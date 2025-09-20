import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/book_import_service.dart';
import '../services/enhanced_txt_import_service.dart';
import '../services/webview_book_parser.dart';
import '../utils/format_detector.dart';

/// 增强书籍导入功能使用示例
///
/// 展示了完整的书籍导入流程，包括：
/// - 格式检测和验证
/// - 智能元数据提取
/// - 封面获取
/// - 章节分析
/// - WebView解析集成
class EnhancedImportExample extends StatefulWidget {
  const EnhancedImportExample({super.key});

  @override
  State<EnhancedImportExample> createState() => _EnhancedImportExampleState();
}

class _EnhancedImportExampleState extends State<EnhancedImportExample> {
  final _txtService = EnhancedTxtImportService();
  final _webViewParser = WebViewBookParser();

  bool _isProcessing = false;
  String _status = '准备导入书籍';
  List<String> _logs = [];

  @override
  void dispose() {
    _webViewParser.dispose();
    super.dispose();
  }

  /// 添加日志
  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
    debugPrint('Import Example: $message');
  }

  /// 演示完整的书籍导入流程
  Future<void> _demonstrateImport() async {
    setState(() {
      _isProcessing = true;
      _status = '开始导入演示';
      _logs.clear();
    });

    try {
      _addLog('🚀 启动增强导入演示');

      // 1. 演示格式检测
      await _demonstrateFormatDetection();

      // 2. 演示TXT导入增强
      await _demonstrateTxtImport();

      // 3. 演示WebView解析
      await _demonstrateWebViewParsing();

      // 4. 演示封面提取
      await _demonstrateCoverExtraction();

      _addLog('✅ 导入演示完成');
      setState(() {
        _status = '演示完成';
      });
    } catch (e) {
      _addLog('❌ 演示失败: $e');
      setState(() {
        _status = '演示失败';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// 演示格式检测功能
  Future<void> _demonstrateFormatDetection() async {
    _addLog('📋 开始格式检测演示');

    // 模拟不同格式的文件检测
    final formats = ['EPUB', 'PDF', 'MOBI', 'FB2', 'TXT', 'CBZ'];

    for (final format in formats) {
      final details = FormatDetector.getFormatInfo(format);
      _addLog('📖 ${details.name}: ${details.description}');
      _addLog('   支持扩展名: ${details.extensions.join(', ')}');
      _addLog('   支持级别: ${details.supportLevel}');

      await Future.delayed(const Duration(milliseconds: 200));
    }

    _addLog('✅ 格式检测演示完成');
  }

  /// 演示TXT导入增强功能
  Future<void> _demonstrateTxtImport() async {
    _addLog('📝 开始TXT导入增强演示');

    // 模拟TXT文件内容
    const sampleTxtContent = '''
书名：《示例小说》
作者：张三

第一章 开始

这是一个示例文本文件，用于演示增强的TXT导入功能。
系统可以智能提取标题、作者信息，并自动分析章节结构。

第二章 发展

智能编码检测确保中文内容正确显示，
支持多种编码格式包括UTF-8、GBK等。

第三章 结束

增强的元数据提取功能可以自动识别：
- 书籍标题
- 作者信息  
- 章节结构
- 语言类型
- 内容统计
''';

    try {
      // 演示元数据提取
      final metadata = _txtService.extractTxtMetadata(
        sampleTxtContent,
        'sample_book.txt',
      );

      _addLog('📚 提取的元数据:');
      _addLog('   标题: ${metadata.title}');
      _addLog('   作者: ${metadata.author}');
      _addLog('   语言: ${metadata.language ?? '未检测'}');
      _addLog('   预估页数: ${metadata.estimatedPages}');

      if (metadata.description != null) {
        _addLog('   简介: ${metadata.description!.substring(0, 50)}...');
      }

      // 演示章节分析
      final chapters = _txtService.analyzeChapterStructure(sampleTxtContent);
      _addLog('📑 章节分析结果:');
      for (final chapter in chapters) {
        _addLog('   ${chapter.title} (层级: ${chapter.level})');
      }
    } catch (e) {
      _addLog('❌ TXT导入演示失败: $e');
    }

    _addLog('✅ TXT导入演示完成');
  }

  /// 演示WebView解析功能
  Future<void> _demonstrateWebViewParsing() async {
    _addLog('🌐 开始WebView解析演示');

    try {
      // 启动WebView解析服务
      final port = await _webViewParser.startLocalServer();
      _addLog('🖥️ 本地服务器启动成功，端口: $port');

      _addLog('📖 WebView解析支持的格式:');
      for (final format in WebViewBookParser.supportedFormats) {
        _addLog('   - $format');
      }

      _addLog('💡 WebView解析特性:');
      _addLog('   - 使用foliate-js引擎');
      _addLog('   - 支持JavaScript元数据提取');
      _addLog('   - 自动封面提取');
      _addLog('   - 多格式兼容性');

      // 停止服务器
      await _webViewParser.stopLocalServer();
      _addLog('🔌 本地服务器已停止');
    } catch (e) {
      _addLog('❌ WebView解析演示失败: $e');
    }

    _addLog('✅ WebView解析演示完成');
  }

  /// 演示封面提取功能
  Future<void> _demonstrateCoverExtraction() async {
    _addLog('🖼️ 开始封面提取演示');

    final coverFormats = {
      'EPUB': '支持多种封面提取策略，包括manifest查找和图片目录扫描',
      'PDF': '提取第一页作为封面，支持自定义分辨率',
      'MOBI': '通过WebView和foliate-js提取内嵌封面',
      'FB2': '从XML binary标签中提取base64编码的封面',
    };

    for (final entry in coverFormats.entries) {
      _addLog('🎨 ${entry.key}格式封面提取:');
      _addLog('   ${entry.value}');
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _addLog('🔍 封面提取特性:');
    _addLog('   - 智能格式识别');
    _addLog('   - 多种提取策略');
    _addLog('   - 图片格式验证');
    _addLog('   - 自动fallback处理');

    _addLog('✅ 封面提取演示完成');
  }

  /// 显示支持的格式信息
  Widget _buildSupportedFormats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📚 支持的格式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...FormatDetector.supportedFormats.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.book, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${entry.key}: ${entry.value.join(', ')}'),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 显示功能特性
  Widget _buildFeatures() {
    final features = [
      '🧠 智能编码检测 - 支持UTF-8、GBK等多种编码',
      '📖 增强元数据提取 - 智能识别标题、作者、简介',
      '📑 智能章节分析 - 自动识别章节结构和层级',
      '🌐 WebView解析引擎 - 集成foliate-js解析多种格式',
      '🖼️ 增强封面提取 - 支持多种格式的封面获取',
      '🔍 智能格式检测 - 基于文件签名和内容分析',
      '📱 跨平台兼容 - 支持iOS、Android、Desktop',
      '⚡ 高性能处理 - 优化的分页和渲染算法',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✨ 功能特性',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...features.map((feature) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(feature),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('增强导入功能演示'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 状态显示
            Card(
              color: _isProcessing
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_isProcessing) const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 演示按钮
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _demonstrateImport,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始演示'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            // 支持的格式
            _buildSupportedFormats(),

            const SizedBox(height: 16),

            // 功能特性
            _buildFeatures(),

            const SizedBox(height: 16),

            // 日志显示
            if (_logs.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.terminal),
                          const SizedBox(width: 8),
                          const Text(
                            '演示日志',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _logs.clear();
                              });
                            },
                            icon: const Icon(Icons.clear),
                            tooltip: '清空日志',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _logs.map((log) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  log,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 书籍导入管理器示例
///
/// 展示如何集成所有新功能进行实际的书籍导入
class BookImportManager {
  final BookImportService _importService = BookImportService();

  /// 完整的书籍导入流程
  Future<ImportResult> importBookFile(File file) async {
    try {
      // 1. 格式检测和验证
      final validation = await FormatDetector.validateBookFile(file);
      if (!validation.isValid) {
        return ImportResult.failure(
          '文件验证失败',
          errors: validation.errors,
          warnings: validation.warnings,
        );
      }

      // 2. 提取元数据
      final fileBytes = await file.readAsBytes();
      final pickedFile = MockPlatformFile(
        name: file.path.split('/').last,
        bytes: fileBytes,
        extension: validation.formatInfo.extension,
      );

      // 这里应该调用公共的导入方法
      // final metadata = await _importService.importBook();
      // 演示目的，创建模拟元数据
      final metadata = EnhancedBookMetadata(
        title: 'Sample Book',
        author: 'Sample Author',
        estimatedPages: 100,
      );

      // 3. 保存到数据库
      // 这里应该调用实际的数据库保存逻辑

      return ImportResult.success(
        '导入成功',
        metadata: metadata,
        formatInfo: validation.formatInfo,
      );
    } catch (e) {
      return ImportResult.failure('导入失败: $e');
    }
  }
}

/// 模拟PlatformFile用于演示
class MockPlatformFile {
  final String name;
  final Uint8List bytes;
  final String? extension;

  MockPlatformFile({required this.name, required this.bytes, this.extension});
}

/// 导入结果模型
class ImportResult {
  final bool isSuccess;
  final String message;
  final EnhancedBookMetadata? metadata;
  final FormatInfo? formatInfo;
  final List<String> errors;
  final List<String> warnings;

  ImportResult._({
    required this.isSuccess,
    required this.message,
    this.metadata,
    this.formatInfo,
    this.errors = const [],
    this.warnings = const [],
  });

  factory ImportResult.success(
    String message, {
    EnhancedBookMetadata? metadata,
    FormatInfo? formatInfo,
  }) {
    return ImportResult._(
      isSuccess: true,
      message: message,
      metadata: metadata,
      formatInfo: formatInfo,
    );
  }

  factory ImportResult.failure(
    String message, {
    List<String> errors = const [],
    List<String> warnings = const [],
  }) {
    return ImportResult._(
      isSuccess: false,
      message: message,
      errors: errors,
      warnings: warnings,
    );
  }
}
