import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 后台内容加载进度
class BackgroundLoadProgress {
  final int loadedBytes;
  final int totalBytes;
  final bool isComplete;
  final String? error;

  BackgroundLoadProgress({
    required this.loadedBytes,
    required this.totalBytes,
    this.isComplete = false,
    this.error,
  });

  double get progress => totalBytes > 0 ? loadedBytes / totalBytes : 0.0;
  
  double get progressPercent => progress * 100;
}

/// 后台内容加载结果
class BackgroundLoadResult {
  final String fullContent; // 完整内容（首批+后台加载）
  final String firstPart; // 首批内容
  final String remainingPart; // 后台加载的内容
  final bool hasRemaining; // 是否有后台加载的内容

  BackgroundLoadResult({
    required this.fullContent,
    required this.firstPart,
    required this.remainingPart,
    required this.hasRemaining,
  });
}

/// 后台内容加载服务
/// 
/// 负责大文件的渐进式加载：先快速返回前N MB，后台继续加载剩余内容
class BackgroundContentLoader {
  // 使用StreamController通知加载进度
  final _progressController = StreamController<BackgroundLoadProgress>.broadcast();
  final _resultController = StreamController<BackgroundLoadResult>.broadcast();
  
  Stream<BackgroundLoadProgress> get progressStream => _progressController.stream;
  Stream<BackgroundLoadResult> get resultStream => _resultController.stream;

  /// 加载大文件（渐进式）
  /// 
  /// 返回首批内容，同时在后台继续加载剩余部分
  Future<BackgroundLoadResult> loadLargeFile({
    required File file,
    required int initialChunkMB,
  }) async {
    final fileSize = await file.length();
    final fileSizeMB = fileSize / 1024 / 1024;
    final initialBytes = initialChunkMB * 1024 * 1024;

    debugPrint('📖 后台加载服务: 文件大小 ${fileSizeMB.toStringAsFixed(2)} MB');
    debugPrint('   首批加载: $initialChunkMB MB');

    // 第一阶段：快速读取首批内容
    final firstPart = await _loadChunk(file, 0, initialBytes.clamp(0, fileSize));
    
    // 如果文件不大，直接返回完整内容
    if (fileSize <= initialBytes) {
      debugPrint('✅ 文件较小，无需后台加载');
      final result = BackgroundLoadResult(
        fullContent: firstPart,
        firstPart: firstPart,
        remainingPart: '',
        hasRemaining: false,
      );
      _resultController.add(result);
      return result;
    }

    // 第二阶段：启动后台加载任务
    final remainingSize = fileSize - initialBytes;
    debugPrint('⚡ 启动后台加载任务: ${(remainingSize / 1024 / 1024).toStringAsFixed(2)} MB');
    
    // 立即返回首批结果，不等待后台加载
    final initialResult = BackgroundLoadResult(
      fullContent: firstPart,
      firstPart: firstPart,
      remainingPart: '',
      hasRemaining: true,
    );

    // 异步加载剩余内容
    _loadRemainingContent(file, initialBytes, fileSize, firstPart);

    return initialResult;
  }

  /// 加载文件块
  Future<String> _loadChunk(File file, int start, int end) async {
    final buffer = StringBuffer();
    final stream = file.openRead(start, end);

    await for (var chunk in stream) {
      buffer.write(utf8.decode(chunk, allowMalformed: true));
    }

    return buffer.toString();
  }

  /// 后台加载剩余内容
  void _loadRemainingContent(
    File file,
    int startByte,
    int totalSize,
    String firstPart,
  ) {
    Future.microtask(() async {
      try {
        debugPrint('🔄 后台加载开始...');
        
        final buffer = StringBuffer();
        final remainingStream = file.openRead(startByte, totalSize);
        
        int loadedBytes = startByte;
        int chunkCount = 0;

        await for (var chunk in remainingStream) {
          buffer.write(utf8.decode(chunk, allowMalformed: true));
          loadedBytes += chunk.length;
          chunkCount++;
          
          // 每加载1MB或每50个chunk报告一次进度
          if (chunkCount % 50 == 0 || loadedBytes >= totalSize) {
            _progressController.add(BackgroundLoadProgress(
              loadedBytes: loadedBytes,
              totalBytes: totalSize,
              isComplete: loadedBytes >= totalSize,
            ));
            
            final progress = loadedBytes / totalSize * 100;
            debugPrint('   后台加载进度: ${progress.toStringAsFixed(1)}%');
          }
        }
        
        final remainingContent = buffer.toString();
        final fullContent = firstPart + remainingContent;
        
        debugPrint('✅ 后台加载完成: ${remainingContent.length} 字符');
        debugPrint('   总内容: ${fullContent.length} 字符');
        
        // 发送完整结果
        final result = BackgroundLoadResult(
          fullContent: fullContent,
          firstPart: firstPart,
          remainingPart: remainingContent,
          hasRemaining: true,
        );
        
        _resultController.add(result);
        
        // 发送完成进度
        _progressController.add(BackgroundLoadProgress(
          loadedBytes: totalSize,
          totalBytes: totalSize,
          isComplete: true,
        ));
        
      } catch (e) {
        debugPrint('❌ 后台加载失败: $e');
        _progressController.add(BackgroundLoadProgress(
          loadedBytes: startByte,
          totalBytes: totalSize,
          isComplete: false,
          error: e.toString(),
        ));
      }
    });
  }

  /// 清理资源
  void dispose() {
    _progressController.close();
    _resultController.close();
  }
}

