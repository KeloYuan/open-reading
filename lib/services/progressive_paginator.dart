import 'dart:async';
import 'package:flutter/material.dart';
import 'simple_text_paginator.dart';

/// 渐进式分页进度回调
typedef ProgressivePaginationCallback = void Function({
  required List<String> pages,
  required int totalPages,
  required bool isComplete,
  required String stage,
});

/// 渐进式分页参数
class ProgressivePaginationParams {
  final String text;
  final Size screenSize;
  final double fontSize;
  final double lineHeight;
  final EdgeInsets padding;
  final double letterSpacing;
  final double paragraphSpacing;
  final double firstLineIndent;
  final double devicePixelRatio;
  final int initialChunkSizeMB; // 首次加载的大小（MB）

  const ProgressivePaginationParams({
    required this.text,
    required this.screenSize,
    required this.fontSize,
    required this.lineHeight,
    required this.padding,
    this.letterSpacing = 0.0,
    this.paragraphSpacing = 0.0,
    this.firstLineIndent = 0.0,
    this.devicePixelRatio = 1.0,
    this.initialChunkSizeMB = 5,
  });
}

/// Isolate分页参数
class IsolatePaginationParams {
  final String text;
  final double screenWidth;
  final double screenHeight;
  final double fontSize;
  final double lineHeight;
  final double paddingLeft;
  final double paddingRight;
  final double paddingTop;
  final double paddingBottom;
  final double letterSpacing;
  final double paragraphSpacing;
  final double firstLineIndent;
  final double devicePixelRatio;

  const IsolatePaginationParams({
    required this.text,
    required this.screenWidth,
    required this.screenHeight,
    required this.fontSize,
    required this.lineHeight,
    required this.paddingLeft,
    required this.paddingRight,
    required this.paddingTop,
    required this.paddingBottom,
    this.letterSpacing = 0.0,
    this.paragraphSpacing = 0.0,
    this.firstLineIndent = 0.0,
    this.devicePixelRatio = 1.0,
  });
}

/// 分页函数（在主线程执行）
///
/// 注意：由于TextPainter只能在root isolate使用，所以不能用compute
/// 改为在主线程异步执行，分批处理避免卡顿
Future<List<String>> _paginateAsync(IsolatePaginationParams params) async {
  // 让出CPU，避免长时间阻塞
  await Future.delayed(const Duration(milliseconds: 10));

  final result = SimpleTextPaginator.paginate(
    text: params.text,
    screenSize: Size(params.screenWidth, params.screenHeight),
    fontSize: params.fontSize,
    lineHeight: params.lineHeight,
    padding: EdgeInsets.only(
      left: params.paddingLeft,
      right: params.paddingRight,
      top: params.paddingTop,
      bottom: params.paddingBottom,
    ),
    letterSpacing: params.letterSpacing,
    paragraphSpacing: params.paragraphSpacing,
    firstLineIndent: params.firstLineIndent,
    devicePixelRatio: params.devicePixelRatio,
  );
  return result.pages;
}

/// 渐进式分页器
///
/// 先快速加载前面部分内容并分页，用户可以立即开始阅读
/// 然后在后台继续加载剩余内容
class ProgressivePaginator {
  /// 渐进式分页
  ///
  /// 策略：
  /// 1. 首先加载前N MB内容，快速分页并返回（用户可立即阅读）
  /// 2. 后台继续加载剩余内容，分批追加分页结果
  /// 3. 使用isolate处理分页，避免卡UI
  static Future<void> paginateProgressively({
    required ProgressivePaginationParams params,
    required ProgressivePaginationCallback onProgress,
  }) async {
    final totalLength = params.text.length;
    final totalMB = totalLength / (1024 * 1024);

    debugPrint('📖 渐进式分页开始');
    debugPrint('   总文本: ${totalMB.toStringAsFixed(2)} MB (${totalLength}字符)');
    debugPrint('   首次加载: ${params.initialChunkSizeMB} MB');

    // 如果文本小于首次加载大小，直接一次性分页
    if (totalMB <= params.initialChunkSizeMB) {
      debugPrint('   文本较小，直接完整分页');
      await _paginateAll(params, onProgress);
      return;
    }

    // 计算首次加载的字符数
    final initialChars = (params.initialChunkSizeMB * 1024 * 1024).toInt();
    final firstChunk =
        params.text.substring(0, initialChars.clamp(0, totalLength));

    debugPrint(
        '   首批: ${firstChunk.length}字符 (${(firstChunk.length / 1024 / 1024).toStringAsFixed(2)} MB)');

    // 第一阶段：快速分页首批内容
    onProgress(
      pages: [],
      totalPages: 0,
      isComplete: false,
      stage: '正在加载前${params.initialChunkSizeMB}MB内容...',
    );

    final firstPages = await _paginateChunk(
      text: firstChunk,
      params: params,
    );

    debugPrint('✅ 首批分页完成: ${firstPages.length}页');

    // 立即返回首批结果，让用户可以开始阅读
    onProgress(
      pages: firstPages,
      totalPages: firstPages.length,
      isComplete: false,
      stage: '已加载前${params.initialChunkSizeMB}MB，后台继续加载...',
    );

    // 第二阶段：后台加载剩余内容
    _loadRemainingInBackground(
      params: params,
      initialPages: firstPages,
      initialChars: initialChars,
      onProgress: onProgress,
    );
  }

  /// 分页单个文本块（异步执行）
  ///
  /// 由于TextPainter限制，在主线程异步执行，分批处理
  static Future<List<String>> _paginateChunk({
    required String text,
    required ProgressivePaginationParams params,
  }) async {
    try {
      // 在主线程异步执行（TextPainter限制）
      final isolateParams = IsolatePaginationParams(
        text: text,
        screenWidth: params.screenSize.width,
        screenHeight: params.screenSize.height,
        fontSize: params.fontSize,
        lineHeight: params.lineHeight,
        paddingLeft: params.padding.left,
        paddingRight: params.padding.right,
        paddingTop: params.padding.top,
        paddingBottom: params.padding.bottom,
        letterSpacing: params.letterSpacing,
        paragraphSpacing: params.paragraphSpacing,
        firstLineIndent: params.firstLineIndent,
        devicePixelRatio: params.devicePixelRatio,
      );

      return await _paginateAsync(isolateParams);
    } catch (e) {
      debugPrint('❌ 分页失败: $e');
      rethrow;
    }
  }

  /// 后台加载剩余内容
  ///
  /// 异步加载剩余文本，分批追加到分页结果中
  static void _loadRemainingInBackground({
    required ProgressivePaginationParams params,
    required List<String> initialPages,
    required int initialChars,
    required ProgressivePaginationCallback onProgress,
  }) {
    // 在后台异步处理
    Future.microtask(() async {
      try {
        final remainingText = params.text.substring(initialChars);
        final remainingMB = remainingText.length / (1024 * 1024);

        debugPrint('📖 后台加载剩余内容: ${remainingMB.toStringAsFixed(2)} MB');

        // 分批加载剩余内容（每批5MB）
        const chunkSizeMB = 5;
        final chunkSize = chunkSizeMB * 1024 * 1024;
        final allPages = List<String>.from(initialPages);
        int processedChars = 0;

        while (processedChars < remainingText.length) {
          final endIndex =
              (processedChars + chunkSize).clamp(0, remainingText.length);
          final chunk = remainingText.substring(processedChars, endIndex);

          // 分页当前块
          final chunkPages = await _paginateChunk(
            text: chunk,
            params: params,
          );

          allPages.addAll(chunkPages);
          processedChars = endIndex;

          final progress = processedChars / remainingText.length;
          debugPrint(
              '   后台进度: ${(progress * 100).toStringAsFixed(1)}% (共${allPages.length}页)');

          // 更新进度
          onProgress(
            pages: allPages,
            totalPages: allPages.length,
            isComplete: processedChars >= remainingText.length,
            stage: processedChars >= remainingText.length
                ? '加载完成'
                : '后台加载中 ${(progress * 100).toStringAsFixed(0)}%...',
          );

          // 让出CPU，避免长时间占用
          await Future.delayed(const Duration(milliseconds: 50));
        }

        debugPrint('✅ 全部内容加载完成: ${allPages.length}页');
      } catch (e) {
        debugPrint('❌ 后台加载失败: $e');
        onProgress(
          pages: initialPages,
          totalPages: initialPages.length,
          isComplete: true,
          stage: '部分加载失败，已显示前${params.initialChunkSizeMB}MB内容',
        );
      }
    });
  }

  /// 一次性完整分页（适用于小文件）
  ///
  /// 对于较小的文件，直接完整分页更高效
  static Future<void> _paginateAll(
    ProgressivePaginationParams params,
    ProgressivePaginationCallback onProgress,
  ) async {
    try {
      onProgress(
        pages: [],
        totalPages: 0,
        isComplete: false,
        stage: '正在分页...',
      );

      final pages = await _paginateChunk(text: params.text, params: params);

      onProgress(
        pages: pages,
        totalPages: pages.length,
        isComplete: true,
        stage: '加载完成',
      );
    } catch (e) {
      debugPrint('❌ 分页失败: $e');
      rethrow;
    }
  }

  /// 快速分页（仅用于预览，不使用isolate）
  ///
  /// 用于需要同步返回结果的场景，但可能会卡UI
  static List<String> paginateSync({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineHeight,
    required EdgeInsets padding,
    double letterSpacing = 0.0,
    double paragraphSpacing = 0.0,
    double firstLineIndent = 0.0,
    double devicePixelRatio = 1.0,
  }) {
    final result = SimpleTextPaginator.paginate(
      text: text,
      screenSize: screenSize,
      fontSize: fontSize,
      lineHeight: lineHeight,
      padding: padding,
      letterSpacing: letterSpacing,
      paragraphSpacing: paragraphSpacing,
      firstLineIndent: firstLineIndent,
      devicePixelRatio: devicePixelRatio,
    );
    return result.pages;
  }
}
