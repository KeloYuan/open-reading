import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// 增强的文件格式检测器
///
/// 提供准确的文件格式识别，支持多种电子书和文档格式
/// 基于文件头部签名和内容分析进行检测
///
/// 核心功能：
/// - [detectFormat] 检测文件格式
/// - [validateBookFile] 验证书籍文件有效性
/// - [isSupported] 检查格式是否支持
/// - [getFormatInfo] 获取格式详细信息
class FormatDetector {
  /// 支持的书籍格式
  static const Map<String, List<String>> supportedFormats = {
    'EPUB': ['epub'],
    'PDF': ['pdf'],
    'MOBI': ['mobi', 'azw', 'azw3'],
    'FictionBook': ['fb2'],
    'Text': ['txt'],
    'Rich Text': ['rtf'],
    'Comic Book': ['cbz', 'cbr'],
    'Microsoft Word': ['doc', 'docx'],
  };

  /// 文件头部签名映射
  static const Map<String, List<int>> fileSignatures = {
    'PDF': [0x25, 0x50, 0x44, 0x46], // %PDF
    'EPUB': [0x50, 0x4B, 0x03, 0x04], // ZIP signature (EPUB is ZIP-based)
    'MOBI': [0x54, 0x50, 0x5A, 0x33], // TPZ3 or BOOKMOBI
    'ZIP': [0x50, 0x4B, 0x03, 0x04], // ZIP
    'RAR': [0x52, 0x61, 0x72, 0x21], // Rar!
    'RTF': [0x7B, 0x5C, 0x72, 0x74], // {\rt
  };

  /// 检测文件格式
  ///
  /// 结合文件扩展名和文件头部签名进行检测
  ///
  /// [file] 要检测的文件
  /// Returns: 检测到的格式信息
  /// Throws: [FileSystemException] 当文件不存在或无法读取时
  static Future<FormatInfo> detectFormat(File file) async {
    try {
      // 1. 基本文件检查
      if (!await file.exists()) {
        throw FileSystemException('文件不存在', file.path);
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw FileSystemException('文件为空', file.path);
      }

      // 2. 从文件名获取扩展名
      final extension = path.extension(file.path).toLowerCase().substring(1);

      // 3. 读取文件头部用于签名检测
      final headerBytes = await _readFileHeader(file);

      // 4. 检测格式
      final detectedFormat = await _detectBySignature(headerBytes, extension);

      // 5. 验证内容
      final isValid = await _validateContent(file, detectedFormat);

      return FormatInfo(
        format: detectedFormat,
        extension: extension,
        isValid: isValid,
        fileSize: fileSize,
        mimeType: _getMimeType(detectedFormat),
        isSupported: _isFormatSupported(detectedFormat),
        confidence: _calculateConfidence(
          detectedFormat,
          extension,
          headerBytes,
        ),
      );
    } catch (e) {
      debugPrint('Format detection failed: $e');
      return FormatInfo(
        format: 'Unknown',
        extension: path.extension(file.path).toLowerCase().substring(1),
        isValid: false,
        fileSize: 0,
        mimeType: 'application/octet-stream',
        isSupported: false,
        confidence: 0.0,
      );
    }
  }

  /// 读取文件头部字节
  static Future<Uint8List> _readFileHeader(File file, {int bytes = 512}) async {
    final randomAccessFile = await file.open();
    try {
      final headerBytes = await randomAccessFile.read(bytes);
      return Uint8List.fromList(headerBytes);
    } finally {
      await randomAccessFile.close();
    }
  }

  /// 通过文件签名检测格式
  static Future<String> _detectBySignature(
    Uint8List headerBytes,
    String extension,
  ) async {
    // 1. 优先检查明确的文件签名
    if (_checkSignature(headerBytes, fileSignatures['PDF']!)) {
      return 'PDF';
    }

    if (_checkSignature(headerBytes, fileSignatures['RTF']!)) {
      return 'RTF';
    }

    // 2. 检查MOBI格式（多种可能的签名）
    if (_isMobiFormat(headerBytes)) {
      return 'MOBI';
    }

    // 3. 检查ZIP-based格式（EPUB, CBZ）
    if (_checkSignature(headerBytes, fileSignatures['ZIP']!)) {
      if (extension == 'epub') {
        return await _validateEpubContent(headerBytes) ? 'EPUB' : 'ZIP';
      } else if (extension == 'cbz') {
        return 'CBZ';
      }
      return 'ZIP';
    }

    // 4. 检查RAR-based格式（CBR）
    if (_checkSignature(headerBytes, fileSignatures['RAR']!)) {
      if (extension == 'cbr') {
        return 'CBR';
      }
      return 'RAR';
    }

    // 5. 检查FB2格式（XML-based）
    if (_isFb2Format(headerBytes)) {
      return 'FB2';
    }

    // 6. 检查文本格式
    if (_isTextFormat(headerBytes)) {
      return 'TXT';
    }

    // 7. 根据扩展名推断
    return _getFormatByExtension(extension);
  }

  /// 检查文件签名
  static bool _checkSignature(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;

    for (int i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  /// 检查是否为MOBI格式
  static bool _isMobiFormat(Uint8List bytes) {
    if (bytes.length < 100) return false;

    // 检查MOBI格式的多种签名
    final mobiSignatures = ['BOOKMOBI', 'TPZ3', 'MOBI'];

    final headerString = String.fromCharCodes(bytes.take(100));
    return mobiSignatures.any((sig) => headerString.contains(sig));
  }

  /// 验证EPUB内容
  static Future<bool> _validateEpubContent(Uint8List bytes) async {
    // 检查ZIP内容中是否包含EPUB特征文件
    final headerString = String.fromCharCodes(bytes.take(512));
    return headerString.contains('mimetype') ||
        headerString.contains('META-INF') ||
        headerString.contains('OEBPS');
  }

  /// 检查是否为FB2格式
  static bool _isFb2Format(Uint8List bytes) {
    if (bytes.length < 50) return false;

    final headerString = String.fromCharCodes(bytes.take(200));
    return headerString.contains('<?xml') &&
        (headerString.contains('FictionBook') ||
            headerString.contains('<body>') ||
            headerString.contains('<description>'));
  }

  /// 检查是否为文本格式
  static bool _isTextFormat(Uint8List bytes) {
    if (bytes.isEmpty) return false;

    // 检查是否包含过多的二进制字符
    int binaryCount = 0;
    final sampleSize = bytes.length.clamp(0, 1024);

    for (int i = 0; i < sampleSize; i++) {
      final byte = bytes[i];
      // 控制字符（除了常见的空白字符）
      if (byte < 32 && byte != 9 && byte != 10 && byte != 13) {
        binaryCount++;
      }
    }

    // 如果二进制字符超过5%，可能不是文本文件
    return binaryCount / sampleSize < 0.05;
  }

  /// 根据扩展名获取格式
  static String _getFormatByExtension(String extension) {
    for (final entry in supportedFormats.entries) {
      if (entry.value.contains(extension)) {
        return entry.key;
      }
    }
    return 'Unknown';
  }

  /// 验证文件内容
  static Future<bool> _validateContent(File file, String format) async {
    try {
      switch (format.toUpperCase()) {
        case 'PDF':
          return await _validatePdfContent(file);
        case 'EPUB':
          return await _validateEpubStructure(file);
        case 'TXT':
          return await _validateTextContent(file);
        case 'FB2':
          return await _validateFb2Content(file);
        default:
          return true; // 其他格式暂时认为有效
      }
    } catch (e) {
      debugPrint('Content validation failed for $format: $e');
      return false;
    }
  }

  /// 验证PDF内容
  static Future<bool> _validatePdfContent(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final content = String.fromCharCodes(bytes.take(1024));
      return content.contains('%PDF-') && content.contains('%%EOF');
    } catch (e) {
      return false;
    }
  }

  /// 验证EPUB结构
  static Future<bool> _validateEpubStructure(File file) async {
    // 这里可以使用Archive包来验证EPUB的ZIP结构
    // 简化实现：检查文件大小和扩展名
    try {
      final size = await file.length();
      return size > 1024; // EPUB文件通常大于1KB
    } catch (e) {
      return false;
    }
  }

  /// 验证文本内容
  static Future<bool> _validateTextContent(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return false;

      // 尝试解码为文本
      final content = String.fromCharCodes(bytes);
      return content.isNotEmpty && content.length > 10;
    } catch (e) {
      return false;
    }
  }

  /// 验证FB2内容
  static Future<bool> _validateFb2Content(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final content = String.fromCharCodes(bytes.take(2048));
      return content.contains('<?xml') && content.contains('FictionBook');
    } catch (e) {
      return false;
    }
  }

  /// 获取MIME类型
  static String _getMimeType(String format) {
    switch (format.toUpperCase()) {
      case 'PDF':
        return 'application/pdf';
      case 'EPUB':
        return 'application/epub+zip';
      case 'MOBI':
        return 'application/x-mobipocket-ebook';
      case 'FB2':
        return 'application/x-fictionbook+xml';
      case 'TXT':
        return 'text/plain';
      case 'RTF':
        return 'application/rtf';
      case 'CBZ':
        return 'application/vnd.comicbook+zip';
      case 'CBR':
        return 'application/vnd.comicbook-rar';
      default:
        return 'application/octet-stream';
    }
  }

  /// 检查格式是否支持
  static bool _isFormatSupported(String format) {
    return supportedFormats.keys.any(
      (key) => key.toUpperCase() == format.toUpperCase(),
    );
  }

  /// 计算检测置信度
  static double _calculateConfidence(
    String format,
    String extension,
    Uint8List bytes,
  ) {
    double confidence = 0.0;

    // 扩展名匹配加分
    if (supportedFormats.values.any((exts) => exts.contains(extension))) {
      confidence += 0.3;
    }

    // 文件签名匹配加分
    if (format != 'Unknown' && format != _getFormatByExtension(extension)) {
      confidence += 0.5; // 基于内容检测的加分
    } else if (format == _getFormatByExtension(extension)) {
      confidence += 0.7; // 扩展名和内容一致
    }

    // 文件大小合理性
    if (bytes.length > 100) {
      confidence += 0.2;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// 验证书籍文件
  ///
  /// 检查文件是否为有效的书籍文件
  ///
  /// [file] 要验证的文件
  /// Returns: 验证结果
  static Future<ValidationResult> validateBookFile(File file) async {
    try {
      final formatInfo = await detectFormat(file);

      final errors = <String>[];
      final warnings = <String>[];

      // 检查格式支持
      if (!formatInfo.isSupported) {
        errors.add('不支持的文件格式: ${formatInfo.format}');
      }

      // 检查文件有效性
      if (!formatInfo.isValid) {
        errors.add('文件格式无效或已损坏');
      }

      // 检查文件大小
      if (formatInfo.fileSize < 1024) {
        warnings.add('文件大小异常小 (${formatInfo.fileSize} bytes)');
      } else if (formatInfo.fileSize > 500 * 1024 * 1024) {
        warnings.add(
          '文件大小过大 (${(formatInfo.fileSize / 1024 / 1024).toStringAsFixed(1)} MB)',
        );
      }

      // 检查置信度
      if (formatInfo.confidence < 0.5) {
        warnings.add('格式检测置信度较低 (${(formatInfo.confidence * 100).toInt()}%)');
      }

      return ValidationResult(
        isValid: errors.isEmpty,
        formatInfo: formatInfo,
        errors: errors,
        warnings: warnings,
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        formatInfo: FormatInfo(
          format: 'Unknown',
          extension: '',
          isValid: false,
          fileSize: 0,
          mimeType: 'application/octet-stream',
          isSupported: false,
          confidence: 0.0,
        ),
        errors: ['文件验证失败: $e'],
        warnings: [],
      );
    }
  }

  /// 检查格式是否支持
  static bool isSupported(String format) {
    return _isFormatSupported(format);
  }

  /// 获取格式信息
  static FormatDetails getFormatInfo(String format) {
    switch (format.toUpperCase()) {
      case 'EPUB':
        return FormatDetails(
          name: 'EPUB',
          fullName: 'Electronic Publication',
          description: '开放的电子书标准格式，支持丰富的排版和多媒体内容',
          extensions: ['epub'],
          category: 'E-book',
          supportLevel: 'Full',
        );
      case 'PDF':
        return FormatDetails(
          name: 'PDF',
          fullName: 'Portable Document Format',
          description: '便携式文档格式，保持原始版式和格式',
          extensions: ['pdf'],
          category: 'Document',
          supportLevel: 'Full',
        );
      case 'MOBI':
        return FormatDetails(
          name: 'MOBI',
          fullName: 'Mobipocket',
          description: 'Amazon Kindle设备的原生格式',
          extensions: ['mobi', 'azw', 'azw3'],
          category: 'E-book',
          supportLevel: 'Full',
        );
      case 'FB2':
        return FormatDetails(
          name: 'FB2',
          fullName: 'FictionBook',
          description: '开源的电子书格式，流行于俄语地区',
          extensions: ['fb2'],
          category: 'E-book',
          supportLevel: 'Full',
        );
      case 'TXT':
        return FormatDetails(
          name: 'TXT',
          fullName: 'Plain Text',
          description: '纯文本格式，兼容性最佳',
          extensions: ['txt'],
          category: 'Text',
          supportLevel: 'Enhanced',
        );
      default:
        return FormatDetails(
          name: format,
          fullName: 'Unknown Format',
          description: '未知或不支持的格式',
          extensions: [],
          category: 'Unknown',
          supportLevel: 'None',
        );
    }
  }
}

/// 格式信息模型
class FormatInfo {
  final String format;
  final String extension;
  final bool isValid;
  final int fileSize;
  final String mimeType;
  final bool isSupported;
  final double confidence;

  FormatInfo({
    required this.format,
    required this.extension,
    required this.isValid,
    required this.fileSize,
    required this.mimeType,
    required this.isSupported,
    required this.confidence,
  });

  @override
  String toString() {
    return 'FormatInfo(format: $format, extension: $extension, isValid: $isValid, '
        'fileSize: $fileSize, confidence: ${(confidence * 100).toInt()}%)';
  }
}

/// 验证结果模型
class ValidationResult {
  final bool isValid;
  final FormatInfo formatInfo;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.isValid,
    required this.formatInfo,
    required this.errors,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() {
    return 'ValidationResult(isValid: $isValid, format: ${formatInfo.format}, '
        'errors: ${errors.length}, warnings: ${warnings.length})';
  }
}

/// 格式详细信息模型
class FormatDetails {
  final String name;
  final String fullName;
  final String description;
  final List<String> extensions;
  final String category;
  final String supportLevel;

  FormatDetails({
    required this.name,
    required this.fullName,
    required this.description,
    required this.extensions,
    required this.category,
    required this.supportLevel,
  });
}
