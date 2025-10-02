import 'package:flutter/material.dart';

import '../services/book_import_service.dart';

class ImportBookPage extends StatefulWidget {
  const ImportBookPage({super.key});

  @override
  State<ImportBookPage> createState() => _ImportBookPageState();
}

class _ImportBookPageState extends State<ImportBookPage> {
  bool _isLoading = false;
  double _progress = 0.0;
  String _progressMessage = '';

  /// 导入文件并显示进度
  ///
  /// 异步导入书籍，通过进度回调更新UI状态
  /// 成功后返回上一页，失败则显示错误提示
  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _progress = 0.0;
      _progressMessage = '准备导入...';
    });

    try {
      final book = await BookImportService().importBook(
        progressCallback: (progress, message) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _progressMessage = message;
            });
          }
        },
      );

      if (book != null && mounted) {
        // 直接返回上一页，让用户从书库打开
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _progress = 0.0;
          _progressMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Text(
          '导入书籍',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).colorScheme.surface,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.file_upload_outlined,
                          size: 60,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '选择电子书文件',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '支持 EPUB、PDF、TXT、MOBI 等多种格式',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                      ),
                      const SizedBox(height: 32),
                      if (_isLoading) ...[
                        // 进度条
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: _progress,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _progressMessage,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(_progress * 100).toStringAsFixed(0)}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!_isLoading)
                        ElevatedButton(
                          onPressed: _pickFile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.folder_open),
                              SizedBox(width: 8),
                              Text('选择文件'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
