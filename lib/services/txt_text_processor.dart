import 'package:flutter/foundation.dart';

/// TXT文本预处理服务
/// 
/// 提供TXT文件的文本清理、格式化和优化功能
/// 
/// 核心功能：
/// - [preprocessText] 预处理文本内容
/// - [normalizeLineBreaks] 标准化换行符
/// - [removeExtraSpaces] 移除多余空格
/// - [fixEncodingIssues] 修复编码问题
/// - [optimizeForReading] 优化阅读体验
class TxtTextProcessor {
  
  /// 预处理TXT文本内容
  /// 
  /// 对原始文本进行全面的清理和优化，提升阅读体验
  /// 
  /// [content] 原始文本内容
  /// [options] 处理选项配置
  /// Returns: 处理后的文本内容
  /// 
  /// 使用示例：
  /// ```dart
  /// final processor = TxtTextProcessor();
  /// final cleaned = processor.preprocessText(
  ///   rawContent,
  ///   options: ProcessingOptions(
  ///     removeExtraSpaces: true,
  ///     fixPunctuation: true,
  ///     optimizeLineBreaks: true,
  ///   ),
  /// );
  /// ```
  String preprocessText(String content, {ProcessingOptions? options}) {
    options ??= ProcessingOptions();
    
    String processed = content;
    
    // 1. 标准化换行符
    if (options.normalizeLineBreaks) {
      processed = normalizeLineBreaks(processed);
    }
    
    // 2. 修复编码问题
    if (options.fixEncodingIssues) {
      processed = fixEncodingIssues(processed);
    }
    
    // 3. 移除多余空格
    if (options.removeExtraSpaces) {
      processed = removeExtraSpaces(processed);
    }
    
    // 4. 修复标点符号
    if (options.fixPunctuation) {
      processed = fixPunctuation(processed);
    }
    
    // 5. 优化段落分割
    if (options.optimizeParagraphs) {
      processed = optimizeParagraphs(processed);
    }
    
    // 6. 处理特殊格式
    if (options.handleSpecialFormats) {
      processed = handleSpecialFormats(processed);
    }
    
    // 7. 优化阅读体验
    if (options.optimizeForReading) {
      processed = optimizeForReading(processed);
    }
    
    debugPrint('文本预处理完成：');
    debugPrint('原始长度: ${content.length} 字符');
    debugPrint('处理后长度: ${processed.length} 字符');
    
    return processed;
  }
  
  /// 标准化换行符
  /// 
  /// 将不同平台的换行符统一为\n格式
  String normalizeLineBreaks(String content) {
    return content
        .replaceAll('\r\n', '\n') // Windows格式
        .replaceAll('\r', '\n');   // Mac格式
  }
  
  /// 修复编码问题
  /// 
  /// 修复常见的编码转换问题和乱码
  String fixEncodingIssues(String content) {
    String fixed = content;
    
    // 修复常见的Unicode编码问题
    final unicodeFixes = <String, String>{
      '锟斤拷': '�', // 替换常见乱码
      '銆€': '　',   // 全角空格问题
      '锛燂拷': '？',   // 问号编码问题
      '锛併拷': '！',   // 感叹号编码问题
      '锛屻拷': '，',   // 逗号编码问题
      '锛冦拷': '。',   // 句号编码问题
    };
    
    for (final entry in unicodeFixes.entries) {
      fixed = fixed.replaceAll(entry.key, entry.value);
    }
    
    // 移除不可见控制字符（除了换行、制表符）
    fixed = fixed.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    
    // 修复UTF-8 BOM问题
    if (fixed.startsWith('\uFEFF')) {
      fixed = fixed.substring(1);
    }
    
    return fixed;
  }
  
  /// 移除多余空格
  /// 
  /// 智能处理各种空格情况，保持合理的排版
  String removeExtraSpaces(String content) {
    return content
        // 移除行首行尾空格
        .split('\n')
        .map((line) => line.trim())
        // 压缩多个连续空格为单个空格
        .map((line) => line.replaceAll(RegExp(r' +'), ' '))
        // 移除制表符并替换为空格
        .map((line) => line.replaceAll('\t', ' '))
        .join('\n');
  }
  
  /// 修复标点符号
  /// 
  /// 标准化中英文标点符号的使用
  String fixPunctuation(String content) {
    String fixed = content;
    
    // 中文标点符号标准化映射
    final punctuationFixes = <String, String>{
      // 替换英文标点为中文标点（在中文环境中）
      ',': '，',
      '.': '。',
      ';': '；',
      ':': '：',
      '?': '？',
      '!': '！',
      // 修复括号
      '(': '（',
      ')': '）',
      '[': '【',
      ']': '】',
    };
    
    // 检测内容主要语言
    final chineseCharCount = RegExp(r'[\u4e00-\u9fff]').allMatches(content).length;
    final totalCharCount = content.length;
    final isChinesePrimary = chineseCharCount > totalCharCount * 0.3;
    
    if (isChinesePrimary) {
      // 在中文文本中应用中文标点
      for (final entry in punctuationFixes.entries) {
        // 只在中文字符附近替换
        fixed = fixed.replaceAllMapped(
          RegExp('([\\u4e00-\\u9fff])\\s*${RegExp.escape(entry.key)}'),
          (match) => '${match.group(1)}${entry.value}',
        );
        fixed = fixed.replaceAllMapped(
          RegExp('${RegExp.escape(entry.key)}\\s*([\\u4e00-\\u9fff])'),
          (match) => '${entry.value}${match.group(1)}',
        );
      }
    }
    
    // 修复标点符号前后的空格
    fixed = fixed
        // 中文标点前不应有空格
        .replaceAll(RegExp(r'\s+([，。；：？！）】》」])'), r'$1')
        // 中文标点后不应有多个空格
        .replaceAll(RegExp(r'([，。；：？！（【《「])\s+'), r'$1')
        // 英文标点的标准空格
        .replaceAll(RegExp(r'([.!?])\s*([A-Z])'), r'$1 $2'); // 句号后的大写字母前加空格
    
    return fixed;
  }
  
  /// 优化段落分割
  /// 
  /// 智能识别和优化段落结构
  String optimizeParagraphs(String content) {
    final lines = content.split('\n');
    final processedLines = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.isEmpty) {
        // 跳过多余的空行
        if (processedLines.isNotEmpty && 
            processedLines.last.isNotEmpty) {
          processedLines.add('');
        }
        continue;
      }
      
      // 检测段落开始
      if (_isParagraphStart(line, i, lines)) {
        // 确保段落前有空行
        if (processedLines.isNotEmpty && 
            processedLines.last.isNotEmpty && 
            !_isChapterTitle(processedLines.last)) {
          processedLines.add('');
        }
      }
      
      processedLines.add(line);
    }
    
    return processedLines.join('\n');
  }
  
  /// 处理特殊格式
  /// 
  /// 识别和处理各种特殊文本格式
  String handleSpecialFormats(String content) {
    String processed = content;
    
    // 1. 处理诗歌格式
    processed = _handlePoetryFormat(processed);
    
    // 2. 处理对话格式
    processed = _handleDialogueFormat(processed);
    
    // 3. 处理列表格式
    processed = _handleListFormat(processed);
    
    // 4. 处理引用格式
    processed = _handleQuoteFormat(processed);
    
    return processed;
  }
  
  /// 优化阅读体验
  /// 
  /// 最终的阅读体验优化
  String optimizeForReading(String content) {
    String optimized = content;
    
    // 1. 确保章节标题前后有适当间距
    optimized = _optimizeChapterSpacing(optimized);
    
    // 2. 优化段落间距
    optimized = _optimizeParagraphSpacing(optimized);
    
    // 3. 处理页面分割优化
    optimized = _optimizePageBreaks(optimized);
    
    return optimized;
  }
  
  // 私有辅助方法
  
  /// 检测是否是段落开始
  bool _isParagraphStart(String line, int index, List<String> lines) {
    // 章节标题
    if (_isChapterTitle(line)) return true;
    
    // 对话开始
    if (line.startsWith('"') || line.startsWith('"') || 
        line.startsWith('「') || line.startsWith('『')) return true;
    
    // 段落缩进
    if (line.startsWith('　　') || line.startsWith('  ')) return true;
    
    // 数字开头（可能是列表）
    if (RegExp(r'^\d+[\.、]').hasMatch(line)) return true;
    
    return false;
  }
  
  /// 检测是否是章节标题
  bool _isChapterTitle(String line) {
    final chapterPatterns = [
      RegExp(r'^第[一二三四五六七八九十百千\d]+章'),
      RegExp(r'^Chapter\s+\d+', caseSensitive: false),
      RegExp(r'^\d+\.\s*[^\d]'),
      RegExp(r'^[一二三四五六七八九十]+、'),
    ];
    
    return chapterPatterns.any((pattern) => pattern.hasMatch(line));
  }
  
  /// 处理诗歌格式
  String _handlePoetryFormat(String content) {
    // 检测诗歌特征：短行、韵律等
    final lines = content.split('\n');
    final shortLineCount = lines.where((line) => 
        line.trim().isNotEmpty && line.trim().length < 20).length;
    
    if (shortLineCount > lines.length * 0.6) {
      // 可能是诗歌，保持原有换行
      return content;
    }
    
    return content;
  }
  
  /// 处理对话格式
  String _handleDialogueFormat(String content) {
    return content
        // 确保对话前后有适当间距
        .replaceAll(RegExp(r'\n*(["\"\「\『])'), '\n\n\$1')
        .replaceAll(RegExp(r'(["\"\」\』])\n*'), '\$1\n\n');
  }
  
  /// 处理列表格式
  String _handleListFormat(String content) {
    return content
        // 列表项前确保有换行
        .replaceAll(RegExp(r'([^\n])(\n\d+[\.、])'), '\$1\n\$2')
        .replaceAll(RegExp(r'([^\n])(\n[一二三四五六七八九十]+[\.、])'), '\$1\n\$2');
  }
  
  /// 处理引用格式
  String _handleQuoteFormat(String content) {
    // 处理引用标记
    return content;
  }
  
  /// 优化章节间距
  String _optimizeChapterSpacing(String content) {
    final lines = content.split('\n');
    final processedLines = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (_isChapterTitle(line)) {
        // 章节标题前确保有空行
        if (processedLines.isNotEmpty && processedLines.last.isNotEmpty) {
          processedLines.add('');
        }
        processedLines.add(line);
        // 章节标题后确保有空行
        processedLines.add('');
      } else {
        processedLines.add(line);
      }
    }
    
    return processedLines.join('\n');
  }
  
  /// 优化段落间距
  String _optimizeParagraphSpacing(String content) {
    // 移除过多的空行
    return content.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }
  
  /// 优化页面分割
  String _optimizePageBreaks(String content) {
    // 避免在不合适的位置分页
    return content;
  }
}

/// 文本处理选项配置
class ProcessingOptions {
  /// 是否标准化换行符
  final bool normalizeLineBreaks;
  
  /// 是否修复编码问题
  final bool fixEncodingIssues;
  
  /// 是否移除多余空格
  final bool removeExtraSpaces;
  
  /// 是否修复标点符号
  final bool fixPunctuation;
  
  /// 是否优化段落结构
  final bool optimizeParagraphs;
  
  /// 是否处理特殊格式
  final bool handleSpecialFormats;
  
  /// 是否优化阅读体验
  final bool optimizeForReading;
  
  ProcessingOptions({
    this.normalizeLineBreaks = true,
    this.fixEncodingIssues = true,
    this.removeExtraSpaces = true,
    this.fixPunctuation = true,
    this.optimizeParagraphs = true,
    this.handleSpecialFormats = true,
    this.optimizeForReading = true,
  });
}
