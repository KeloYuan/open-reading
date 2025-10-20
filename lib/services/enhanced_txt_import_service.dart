import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/chapter.dart';
import 'txt_text_processor.dart';
import 'text_preprocessor.dart';
import 'package:gbk_codec/gbk_codec.dart';

/// 增强的TXT文件导入服务
///
/// 提供智能编码检测、元数据提取、章节分析和分页优化功能
///
/// 核心功能：
/// - [detectTextEncoding] 智能检测文本编码
/// - [extractTxtMetadata] 增强元数据提取
/// - [analyzeChapterStructure] 智能章节结构分析
/// - [optimizedPageEstimation] 优化分页估算
class EnhancedTxtImportService {
  final _textProcessor = TxtTextProcessor();
  final _preprocessor = TextPreprocessor();

  /// 智能检测文本编码
  ///
  /// 支持主流中文编码格式：UTF-8、GBK/GB2312、UTF-16
  ///
  /// [bytes] 原始文件字节数据
  /// Returns: 解码后的文本内容
  ///
  /// 编码检测策略：
  /// 1. BOM检测（最可靠）
  /// 2. UTF-8严格模式（现代标准）
  /// 3. GBK/GB2312特征检测（中文旧文件）
  /// 4. UTF-8宽松模式（降级方案）
  String detectTextEncoding(Uint8List bytes) {
    debugPrint('🔍 开始编码检测，文件大小: ${bytes.length} 字节');

    // 显示前16个字节的十六进制值，用于调试
    if (bytes.length >= 16) {
      final hexPreview = bytes
          .take(16)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      debugPrint('📋 文件头: $hexPreview');
    }

    // 1. 检测 BOM (Byte Order Mark)
    // UTF-8 BOM: EF BB BF
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      debugPrint('✅ 检测到 UTF-8 BOM');
      return utf8.decode(bytes.sublist(3));
    }

    // UTF-16 LE BOM: FF FE
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      debugPrint('✅ 检测到 UTF-16 LE BOM');
      return _decodeUtf16LE(bytes.sublist(2));
    }

    // UTF-16 BE BOM: FE FF
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      debugPrint('✅ 检测到 UTF-16 BE BOM');
      return _decodeUtf16BE(bytes.sublist(2));
    }

    // 2. 尝试 UTF-8 严格解码（优先，因为是现代标准）
    debugPrint('📊 步骤1: 尝试 UTF-8 严格模式...');
    try {
      final content = utf8.decode(bytes, allowMalformed: false);
      // 验证解码质量
      if (_isValidUtf8Content(content)) {
        debugPrint('✅ UTF-8 解码成功 (${content.length} 字符)');
        return content;
      }
      debugPrint('⚠️ UTF-8 解码通过，但内容验证失败');
    } catch (e) {
      final errorMsg = e.toString();
      debugPrint(
          '⚠️ UTF-8 严格模式失败: ${errorMsg.length > 100 ? errorMsg.substring(0, 100) : errorMsg}');
    }

    // 3. 检测 GBK/GB2312 特征（中文旧文件常用）
    debugPrint('📊 步骤2: 检测 GBK/GB2312 特征...');
    final gbkScore = _calculateGbkScore(bytes);
    debugPrint('   GBK 特征评分: ${gbkScore.toStringAsFixed(2)}');

    if (gbkScore > 0.3) {
      // 评分>0.3表示很可能是GBK编码
      try {
        final content = gbk.decode(bytes);
        // 如果评分很高(>0.8)，直接接受，不做严格验证
        if (gbkScore > 0.8) {
          debugPrint(
              '✅ GBK/GB2312 解码成功 (高评分: ${gbkScore.toStringAsFixed(2)}, ${content.length} 字符)');
          return content;
        }
        // 评分中等时才做验证
        if (content.isNotEmpty && _isValidGbkContent(content)) {
          debugPrint('✅ GBK/GB2312 解码成功 (${content.length} 字符)');
          return content;
        }
        debugPrint('⚠️ GBK 解码通过，但内容验证失败');
      } catch (e) {
        debugPrint('❌ GBK 解码失败: $e');
      }
    }

    // 4. UTF-8 宽松模式降级
    debugPrint('📊 步骤3: UTF-8 宽松模式...');
    try {
      final content = utf8.decode(bytes, allowMalformed: true);
      if (content.isNotEmpty && !_hasExcessiveReplacementChars(content)) {
        debugPrint('✅ UTF-8 宽松模式成功 (${content.length} 字符)');
        return content;
      }
      debugPrint('⚠️ UTF-8 宽松模式替换字符过多');
    } catch (e) {
      debugPrint('❌ UTF-8 宽松模式失败: $e');
    }

    // 5. 强制尝试 GBK（最后的降级方案）
    debugPrint('📊 步骤4: 强制 GBK 解码...');
    try {
      final content = gbk.decode(bytes);
      if (content.isNotEmpty) {
        debugPrint('⚠️ 强制使用 GBK 解码 (${content.length} 字符)');
        return content;
      }
    } catch (e) {
      debugPrint('❌ 强制 GBK 失败: $e');
    }

    // 6. 最终降级：UTF-8 宽松 + 允许所有错误
    debugPrint('⚠️ 最终降级：UTF-8 宽松模式（允许所有错误）');
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

  /// 计算 GBK 特征评分 (0.0 - 1.0)
  ///
  /// 返回值越高，越可能是 GBK 编码
  double _calculateGbkScore(Uint8List bytes) {
    if (bytes.length < 100) return 0.0;

    int gbkPairCount = 0;
    int totalPairs = 0;
    int validPairs = 0;

    // 检查前 2000 字节
    final checkLength = math.min(bytes.length, 2000);

    for (int i = 0; i < checkLength - 1; i++) {
      final byte1 = bytes[i];

      // GBK 第一字节范围: 0x81-0xFE
      if (byte1 >= 0x81 && byte1 <= 0xFE) {
        totalPairs++;
        final byte2 = bytes[i + 1];

        // GBK 第二字节范围: 0x40-0xFE (除了 0x7F)
        if (byte2 >= 0x40 && byte2 <= 0xFE && byte2 != 0x7F) {
          gbkPairCount++;

          // GB2312 核心区域 (常用汉字): 0xB0-0xF7, 0xA1-0xFE
          if (byte1 >= 0xB0 &&
              byte1 <= 0xF7 &&
              byte2 >= 0xA1 &&
              byte2 <= 0xFE) {
            validPairs++;
          }

          i++; // 跳过第二个字节
        }
      }
    }

    if (totalPairs == 0) return 0.0;

    // 计算匹配率
    final matchRatio = gbkPairCount / totalPairs;

    // 如果有常用汉字区域的字节对，增加权重
    final validRatio = validPairs > 0 ? validPairs / gbkPairCount : 0.0;

    // 综合评分
    final score = matchRatio * 0.7 + validRatio * 0.3;

    debugPrint(
        '   - GBK 字节对: $gbkPairCount/$totalPairs (${(matchRatio * 100).toStringAsFixed(1)}%)');
    debugPrint(
        '   - 常用汉字对: $validPairs (${(validRatio * 100).toStringAsFixed(1)}%)');

    return score;
  }

  /// 验证 UTF-8 内容是否有效
  bool _isValidUtf8Content(String content) {
    if (content.isEmpty) return false;

    // 检查替换字符比例
    final replacementCount = content.codeUnits.where((c) => c == 0xFFFD).length;
    if (replacementCount > content.length * 0.01) {
      debugPrint('   UTF-8 替换字符过多: $replacementCount/${content.length}');
      return false;
    }

    // 检查控制字符比例（排除常见的空白字符）
    final controlCount = content.codeUnits.where((c) {
      return c < 32 && c != 9 && c != 10 && c != 13;
    }).length;

    if (controlCount > content.length * 0.05) {
      debugPrint('   UTF-8 控制字符过多: $controlCount/${content.length}');
      return false;
    }

    return true;
  }

  /// 验证 GBK 解码后的内容是否有效
  bool _isValidGbkContent(String content) {
    if (content.isEmpty) {
      debugPrint('   GBK 内容为空');
      return false;
    }

    // 检查替换字符
    final replacementCount = content.codeUnits.where((c) => c == 0xFFFD).length;
    final replacementRatio = replacementCount / content.length;
    debugPrint(
        '   GBK 替换字符: $replacementCount/${content.length} (${(replacementRatio * 100).toStringAsFixed(2)}%)');

    if (replacementRatio > 0.05) {
      debugPrint('   ❌ GBK 替换字符过多');
      return false;
    }

    // 检查中文字符
    final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(content).length;
    final chineseRatio = chineseCount / content.length;
    debugPrint(
        '   GBK 中文字符: $chineseCount/${content.length} (${(chineseRatio * 100).toStringAsFixed(2)}%)');

    if (chineseCount > 0) {
      debugPrint('   ✅ 包含中文字符，验证通过');
      return true;
    }

    // 即使没有中文，如果内容看起来正常也接受
    final printableCount = content.codeUnits.where((c) {
      return (c >= 32 && c <= 126) || c == 9 || c == 10 || c == 13;
    }).length;
    final printableRatio = printableCount / content.length;
    debugPrint(
        '   GBK 可打印字符: $printableCount/${content.length} (${(printableRatio * 100).toStringAsFixed(2)}%)');

    if (printableRatio > 0.8) {
      debugPrint('   ✅ 可打印字符足够，验证通过');
      return true;
    }

    debugPrint('   ❌ 验证失败');
    return false;
  }

  /// 检查是否有过多的替换字符
  bool _hasExcessiveReplacementChars(String content) {
    final replacementCount = content.codeUnits.where((c) => c == 0xFFFD).length;
    return replacementCount > content.length * 0.1;
  }

  /// 增强的TXT元数据提取
  ///
  /// 智能分析文本内容，提取标题、作者、简介等信息
  ///
  /// [content] 解码后的文本内容
  /// [fileName] 原始文件名
  /// [processText] 是否预处理文本（默认true）
  /// [indentSize] 段首缩进字符数（0-4，默认2）
  /// [compressEmptyLines] 是否压缩空行（默认true）
  /// Returns: 增强的书籍元数据
  TxtMetadata extractTxtMetadata(
    String content,
    String fileName, {
    bool processText = true,
    int indentSize = 2,
    bool compressEmptyLines = true,
  }) {
    // 1. 文本预处理（使用新的TextPreprocessor）
    String processedContent = content;
    if (processText) {
      processedContent = _preprocessor.process(
        content,
        indentSize: indentSize,
        indentDialogue: true,
        compressEmptyLines: compressEmptyLines,
      );
    }

    final lines =
        processedContent.split('\n').map((line) => line.trim()).toList();

    // 1. 智能标题提取
    String title = _extractTitle(lines, fileName);

    // 2. 智能作者提取
    String author = _extractAuthor(lines);

    // 3. 简介提取
    String? description = _extractDescription(lines);

    // 4. 语言检测
    String? language = _detectLanguage(content);

    // 5. 内容统计
    final stats = _analyzeContentStatistics(processedContent, lines);

    // 6. 智能分页估算
    final estimatedPages = _calculateOptimizedPages(processedContent, stats);

    return TxtMetadata(
      title: title,
      author: author,
      description: description,
      language: language,
      estimatedPages: estimatedPages,
      additionalInfo: {
        'format': 'TXT',
        'characterCount': processedContent.length,
        'lineCount': lines.length,
        'paragraphCount': stats['paragraphCount'],
        'averageLineLength': stats['averageLineLength'],
        'encoding': 'auto-detected',
        'hasChapterStructure': stats['hasChapterStructure'],
        'textProcessed': processText,
        'originalLength': content.length,
      },
    );
  }

  /// 智能标题提取
  String _extractTitle(List<String> lines, String fileName) {
    // 策略1: 查找明确的标题标识
    for (int i = 0; i < lines.length.clamp(0, 20); i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      // 匹配标题模式
      final titlePatterns = [
        RegExp(r'^书名[:：]\s*(.+)$'),
        RegExp(r'^标题[:：]\s*(.+)$'),
        RegExp(r'^Title[:：]\s*(.+)$', caseSensitive: false),
        RegExp(r'^《(.+)》$'),
      ];

      for (final pattern in titlePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final title = match.group(1)?.trim();
          if (title != null && title.isNotEmpty && title.length < 100) {
            return title;
          }
        }
      }
    }

    // 策略2: 第一行作为标题（常见格式）
    for (final line in lines.take(5)) {
      if (line.isNotEmpty &&
          line.length > 2 &&
          line.length < 100 &&
          !line.contains('作者') &&
          !line.contains('Author') &&
          !_isCommonPrefix(line)) {
        // 验证是否像标题
        if (_looksLikeTitle(line)) {
          return _cleanTitle(line);
        }
      }
    }

    // 策略3: 从文件名提取
    final fileTitle = fileName.replaceAll(RegExp(r'\.(txt|TXT)$'), '');
    if (fileTitle.isNotEmpty) {
      return _cleanTitle(fileTitle);
    }

    return '未知标题';
  }

  /// 智能作者提取
  String _extractAuthor(List<String> lines) {
    // 策略1: 明确的作者标识
    for (int i = 0; i < lines.length.clamp(0, 30); i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final authorPatterns = [
        RegExp(r'^作者[:：]\s*(.+)$'),
        RegExp(r'^著[:：]\s*(.+)$'),
        RegExp(r'^Author[:：]\s*(.+)$', caseSensitive: false),
        RegExp(r'^By[:：]\s*(.+)$', caseSensitive: false),
        RegExp(r'^文[:：]\s*(.+)$'),
        RegExp(r'^\[(.+)\]\s*著$'),
      ];

      for (final pattern in authorPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final author = match.group(1)?.trim();
          if (author != null && author.isNotEmpty && author.length < 50) {
            return _cleanAuthorName(author);
          }
        }
      }
    }

    // 策略2: 第二行或第三行常见作者位置
    for (int i = 1; i < lines.length.clamp(0, 10); i++) {
      final line = lines[i];
      if (line.isNotEmpty && line.length > 1 && line.length < 30) {
        // 检查是否包含常见作者格式
        if (_looksLikeAuthor(line)) {
          return _cleanAuthorName(line);
        }
      }
    }

    return '未知作者';
  }

  /// 简介提取
  String? _extractDescription(List<String> lines) {
    // 策略1: 查找明确的简介标识
    for (int i = 0; i < lines.length.clamp(0, 50); i++) {
      final line = lines[i].toLowerCase();
      if (line.contains('简介') ||
          line.contains('内容简介') ||
          line.contains('synopsis') ||
          line.contains('summary') ||
          line.contains('description')) {
        // 获取后面几行作为简介
        final descLines = <String>[];
        for (int j = i + 1; j < lines.length.clamp(0, i + 10); j++) {
          final descLine = lines[j].trim();
          if (descLine.isNotEmpty && descLine.length > 20) {
            descLines.add(descLine);
            if (descLines.join(' ').length > 300) break;
          }
        }

        if (descLines.isNotEmpty) {
          return descLines
              .join(' ')
              .substring(0, descLines.join(' ').length.clamp(0, 300));
        }
      }
    }

    // 策略2: 第一个长段落作为简介
    for (int i = 5; i < lines.length.clamp(0, 50); i++) {
      final line = lines[i];
      if (line.length > 50 &&
          line.length < 500 &&
          !_isChapterTitle(line) &&
          !line.contains('第一章') &&
          !line.contains('Chapter 1')) {
        return line.substring(0, line.length.clamp(0, 300));
      }
    }

    return null;
  }

  /// 语言检测（增强版）
  String? _detectLanguage(String content) {
    final sample = content.length > 1000 ? content.substring(0, 1000) : content;

    // 中文字符统计
    final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(sample).length;
    // 英文字符统计
    final englishCount = RegExp(r'[a-zA-Z]').allMatches(sample).length;
    // 日文字符统计
    final japaneseCount = RegExp(
      r'[\u3040-\u309f\u30a0-\u30ff]',
    ).allMatches(sample).length;
    // 韩文字符统计
    final koreanCount = RegExp(r'[\uac00-\ud7af]').allMatches(sample).length;

    final totalChars = sample.length;

    if (chineseCount > totalChars * 0.3) {
      return 'zh-CN';
    } else if (japaneseCount > totalChars * 0.2) {
      return 'ja';
    } else if (koreanCount > totalChars * 0.2) {
      return 'ko';
    } else if (englishCount > totalChars * 0.5) {
      return 'en';
    }

    return null;
  }

  /// 内容统计分析
  Map<String, dynamic> _analyzeContentStatistics(
    String content,
    List<String> lines,
  ) {
    // 段落统计（空行分隔）
    int paragraphCount = 0;
    bool inParagraph = false;

    for (final line in lines) {
      if (line.trim().isNotEmpty) {
        if (!inParagraph) {
          paragraphCount++;
          inParagraph = true;
        }
      } else {
        inParagraph = false;
      }
    }

    // 平均行长度
    final nonEmptyLines =
        lines.where((line) => line.trim().isNotEmpty).toList();
    final averageLineLength = nonEmptyLines.isNotEmpty
        ? nonEmptyLines.map((line) => line.length).reduce((a, b) => a + b) /
            nonEmptyLines.length
        : 0.0;

    // 检查是否有章节结构
    final hasChapterStructure = _detectChapterStructure(lines);

    return {
      'paragraphCount': paragraphCount,
      'averageLineLength': averageLineLength,
      'hasChapterStructure': hasChapterStructure,
      'nonEmptyLineCount': nonEmptyLines.length,
    };
  }

  /// 检测章节结构
  bool _detectChapterStructure(List<String> lines) {
    int chapterCount = 0;

    for (final line in lines) {
      if (_isChapterTitle(line)) {
        chapterCount++;
        if (chapterCount >= 2) return true; // 至少2个章节才算有结构
      }
    }

    return false;
  }

  /// 优化的分页估算
  int _calculateOptimizedPages(String content, Map<String, dynamic> stats) {
    // 基础字符数分页
    final basePages = (content.length / 1500).ceil();

    // 根据内容特征调整
    double adjustmentFactor = 1.0;

    // 1. 根据平均行长度调整
    final avgLineLength = (stats['averageLineLength'] as num).toDouble();
    if (avgLineLength > 50) {
      // 长行文本，增加页数
      adjustmentFactor *= 1.2;
    } else if (avgLineLength < 20) {
      // 短行文本（诗歌等），减少页数
      adjustmentFactor *= 0.8;
    }

    // 2. 根据段落密度调整
    final paragraphCount = stats['paragraphCount'] as int;
    final paragraphDensity = paragraphCount / (content.length / 1000.0);
    if (paragraphDensity > 5) {
      // 段落密集，减少页数
      adjustmentFactor *= 0.9;
    }

    // 3. 根据语言特征调整
    final chineseRatio =
        RegExp(r'[\u4e00-\u9fff]').allMatches(content).length / content.length;
    if (chineseRatio > 0.5) {
      // 中文字符密度高，每页字符数可以多一些
      adjustmentFactor *= 0.9;
    }

    final adjustedPages = (basePages * adjustmentFactor).ceil();
    return adjustedPages.clamp(1, 9999);
  }

  /// 智能章节结构分析
  ///
  /// 自动检测文本中的章节分割点，支持多种章节格式
  ///
  /// [content] 完整文本内容
  /// Returns: 章节列表
  List<Chapter> analyzeChapterStructure(String content) {
    final lines = content.split('\n');
    final chapters = <Chapter>[];

    // 1. 检测章节标题模式
    final chapterPatterns = _getChapterPatterns();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      for (final pattern in chapterPatterns) {
        if (pattern.hasMatch(line)) {
          final chapterTitle = _cleanTitle(line);
          final chapter = Chapter(
            title: chapterTitle,
            startPage: 0, // 稍后计算实际页数
            level: _determineChapterLevel(line),
            order: chapters.length,
          );

          chapters.add(chapter);
          debugPrint('检测到章节: $chapterTitle (第${i + 1}行)');
          break;
        }
      }
    }

    // 2. 如果没有检测到章节，尝试智能分割
    if (chapters.isEmpty) {
      return _intelligentChapterSplit(content);
    }

    // 3. 优化章节结构
    return _optimizeChapterStructure(chapters);
  }

  /// 获取章节模式列表
  List<RegExp> _getChapterPatterns() {
    return [
      // 中文章节
      RegExp(r'^第[一二三四五六七八九十百千\d]+章\s*(.*)$'),
      RegExp(r'^第[一二三四五六七八九十百千\d]+节\s*(.*)$'),
      RegExp(r'^[一二三四五六七八九十]+、\s*(.*)$'),
      RegExp(r'^\d+\.\s*(.*)$'),
      RegExp(r'^[\d]+[\.、]\s*(.*)$'),

      // 英文章节
      RegExp(r'^Chapter\s+\d+\s*(.*)$', caseSensitive: false),
      RegExp(r'^Part\s+\d+\s*(.*)$', caseSensitive: false),
      RegExp(r'^Section\s+\d+\s*(.*)$', caseSensitive: false),

      // 特殊章节
      RegExp(r'^(序言|前言|引言|目录|后记|跋|结语)(.*)$'),
      RegExp(
        r'^(Preface|Introduction|Prologue|Epilogue)(.*)$',
        caseSensitive: false,
      ),

      // 分割线章节
      RegExp(r'^[=\-]{3,}\s*(.+)\s*[=\-]{3,}$'),
      RegExp(r'^\*{3,}\s*(.+)\s*\*{3,}$'),
    ];
  }

  /// 确定章节层级
  int _determineChapterLevel(String title) {
    // 一级章节（主章节）
    if (RegExp(r'第[一二三四五六七八九十百千\d]+章').hasMatch(title) ||
        RegExp(r'Chapter\s+\d+', caseSensitive: false).hasMatch(title) ||
        RegExp(r'Part\s+\d+', caseSensitive: false).hasMatch(title)) {
      return 0;
    }

    // 二级章节（小节）
    if (RegExp(r'第[一二三四五六七八九十\d]+节').hasMatch(title) ||
        RegExp(r'Section\s+\d+', caseSensitive: false).hasMatch(title) ||
        RegExp(r'^\d+\.\d+').hasMatch(title)) {
      return 1;
    }

    // 三级章节
    if (RegExp(r'^\d+\.\d+\.\d+').hasMatch(title) ||
        RegExp(r'[一二三四五六七八九十]+、').hasMatch(title)) {
      return 2;
    }

    return 0; // 默认一级章节
  }

  /// 智能章节分割（当无明确章节标识时）
  List<Chapter> _intelligentChapterSplit(String content) {
    final chapters = <Chapter>[];
    final lines = content.split('\n');

    // 按内容长度自动分割
    const targetChapterLength = 5000; // 每章目标字符数
    int currentLength = 0;
    int chapterStart = 0;
    int chapterIndex = 1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      currentLength += line.length + 1; // +1 for newline

      // 查找合适的分割点
      if (currentLength >= targetChapterLength) {
        // 寻找段落边界
        for (int j = i; j < lines.length.clamp(0, i + 10); j++) {
          if (lines[j].trim().isEmpty && j > i) {
            // 在空行处分割
            final chapter = Chapter(
              title: '第${chapterIndex}章',
              startPage: 0,
              level: 0,
              order: chapters.length,
            );

            chapters.add(chapter);
            chapterStart = j + 1;
            currentLength = 0;
            chapterIndex++;
            i = j;
            break;
          }
        }
      }
    }

    // 添加最后一章
    if (chapterStart < lines.length) {
      final chapter = Chapter(
        title: '第${chapterIndex}章',
        startPage: 0,
        level: 0,
        order: chapters.length,
      );
      chapters.add(chapter);
    }

    return chapters;
  }

  /// 优化章节结构
  List<Chapter> _optimizeChapterStructure(List<Chapter> chapters) {
    // 1. 去重相似章节
    final uniqueChapters = <Chapter>[];
    for (final chapter in chapters) {
      if (!uniqueChapters.any(
        (existing) => _areSimilarTitles(existing.title, chapter.title),
      )) {
        uniqueChapters.add(chapter);
      }
    }

    // 2. 排序章节
    uniqueChapters.sort((a, b) => a.order.compareTo(b.order));

    return uniqueChapters;
  }

  /// 检查标题是否相似
  bool _areSimilarTitles(String title1, String title2) {
    final clean1 = title1.toLowerCase().replaceAll(
          RegExp(r'[^\w\u4e00-\u9fff]'),
          '',
        );
    final clean2 = title2.toLowerCase().replaceAll(
          RegExp(r'[^\w\u4e00-\u9fff]'),
          '',
        );

    if (clean1 == clean2) return true;

    // 计算编辑距离
    if (clean1.length > 5 && clean2.length > 5) {
      final similarity = _calculateSimilarity(clean1, clean2);
      return similarity > 0.8;
    }

    return false;
  }

  /// 计算字符串相似度
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;

    if (longer.length == 0) return 1.0;

    final editDistance = _levenshteinDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length;
  }

  /// 计算编辑距离
  int _levenshteinDistance(String s1, String s2) {
    final costs = List.generate(s2.length + 1, (i) => i);

    for (int i = 1; i <= s1.length; i++) {
      costs[0] = i;
      int nw = i - 1;

      for (int j = 1; j <= s2.length; j++) {
        final cj = math
            .min(
              1 + math.min(costs[j], costs[j - 1]),
              s1[i - 1] == s2[j - 1] ? nw : nw + 1,
            )
            .toInt();
        nw = costs[j];
        costs[j] = cj;
      }
    }

    return costs[s2.length];
  }

  // 辅助方法

  bool _looksLikeTitle(String line) {
    // 标题特征：
    // 1. 长度适中
    // 2. 不包含常见非标题词汇
    // 3. 可能包含书名号

    if (line.length < 2 || line.length > 80) return false;

    final titleKeywords = ['书', '记', '传', '史', '录', '集'];
    final hasBookKeyword = titleKeywords.any(
      (keyword) => line.contains(keyword),
    );

    final hasBookmarks = line.contains('《') && line.contains('》');

    // 排除常见非标题格式
    final excludePatterns = [
      RegExp(r'^\d{4}[-/]\d{1,2}[-/]\d{1,2}'), // 日期
      RegExp(r'^第\d+页'), // 页码
      RegExp(r'版权|Copyright', caseSensitive: false), // 版权信息
    ];

    final isExcluded = excludePatterns.any((pattern) => pattern.hasMatch(line));

    return (hasBookKeyword || hasBookmarks) && !isExcluded;
  }

  bool _looksLikeAuthor(String line) {
    // 作者特征：
    // 1. 长度适中（通常人名不会太长）
    // 2. 包含常见作者格式

    if (line.length < 2 || line.length > 20) return false;

    // 中文姓氏
    final chineseSurnames = ['李', '王', '张', '刘', '陈', '杨', '赵', '黄', '周', '吴'];
    final hasChineseSurname = chineseSurnames.any(
      (surname) => line.startsWith(surname),
    );

    // 英文名格式
    final englishNamePattern = RegExp(r'^[A-Z][a-z]+\s+[A-Z][a-z]+$');

    // 排除明显不是作者的内容
    final excludeWords = ['第', '章', '节', '页', '版', '年', '月', '日'];
    final hasExcludeWord = excludeWords.any((word) => line.contains(word));

    return (hasChineseSurname || englishNamePattern.hasMatch(line)) &&
        !hasExcludeWord;
  }

  bool _isCommonPrefix(String line) {
    final prefixes = [
      '版权所有',
      'Copyright',
      '出版社',
      '发行',
      '印刷',
      '定价',
      '页码',
      '目录',
      'ISBN',
      '作者简介',
      '内容简介',
    ];

    return prefixes.any(
      (prefix) => line.toLowerCase().contains(prefix.toLowerCase()),
    );
  }

  bool _isChapterTitle(String line) {
    final chapterPatterns = _getChapterPatterns();
    return chapterPatterns.any((pattern) => pattern.hasMatch(line));
  }

  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'^[=\-\*\s]+'), '') // 移除开头的装饰符
        .replaceAll(RegExp(r'[=\-\*\s]+$'), '') // 移除结尾的装饰符
        .replaceAll(RegExp(r'\s+'), ' ') // 规范化空格
        .trim();
  }

  String _cleanAuthorName(String author) {
    return author
        .replaceAll(RegExp(r'[()（）\[\]【】]'), '') // 移除括号
        .replaceAll(RegExp(r'\s+'), ' ') // 规范化空格
        .trim();
  }
}

/// TXT元数据模型
class TxtMetadata {
  final String title;
  final String author;
  final String? description;
  final String? language;
  final int estimatedPages;
  final Map<String, dynamic>? additionalInfo;

  TxtMetadata({
    required this.title,
    required this.author,
    this.description,
    this.language,
    required this.estimatedPages,
    this.additionalInfo,
  });
}
