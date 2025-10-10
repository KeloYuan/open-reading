import 'package:flutter/material.dart';
import 'fast_text_paginator.dart';
import 'fast_text_paginator_optimized.dart';

/// 分页性能测试工具
class PaginationBenchmark {
  /// 生成测试文本
  static String generateTestText(int charCount) {
    const sample = '这是一段测试文本，用于测试分页性能。包含了中文、English、数字123和标点符号！？。';
    final buffer = StringBuffer();
    while (buffer.length < charCount) {
      buffer.write(sample);
      if (buffer.length % 1000 == 0) {
        buffer.write('\n\n'); // 添加段落
      }
    }
    return buffer.toString().substring(0, charCount);
  }

  /// 测试旧版分页器（逐字符测量）
  static Future<BenchmarkResult> testOldPaginator({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineSpacing,
    required EdgeInsets padding,
  }) async {
    final stopwatch = Stopwatch()..start();

    final result = await FastTextPaginator.paginateAccurate(
      text: text,
      screenSize: screenSize,
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      padding: padding,
    );

    stopwatch.stop();

    return BenchmarkResult(
      method: '旧版分页器（逐字符）',
      elapsedMs: stopwatch.elapsedMilliseconds,
      pageCount: result.pages.length,
      charCount: text.length,
    );
  }

  /// 测试新版分页器（二分查找）
  static Future<BenchmarkResult> testOptimizedPaginator({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineSpacing,
    required EdgeInsets padding,
  }) async {
    final stopwatch = Stopwatch()..start();

    final result = await OptimizedTextPaginator.paginateFast(
      text: text,
      screenSize: screenSize,
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      padding: padding,
    );

    stopwatch.stop();

    return BenchmarkResult(
      method: '新版分页器（二分查找）',
      elapsedMs: stopwatch.elapsedMilliseconds,
      pageCount: result.pages.length,
      charCount: text.length,
    );
  }

  /// 测试同步分页器（字符宽度缓存）
  static Future<BenchmarkResult> testSyncPaginator({
    required String text,
    required Size screenSize,
    required double fontSize,
    required double lineSpacing,
    required EdgeInsets padding,
  }) async {
    final stopwatch = Stopwatch()..start();

    final result = FastTextPaginator.paginate(
      text: text,
      screenSize: screenSize,
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      padding: padding,
    );

    stopwatch.stop();

    return BenchmarkResult(
      method: '同步分页器（字符宽度缓存）',
      elapsedMs: stopwatch.elapsedMilliseconds,
      pageCount: result.pages.length,
      charCount: text.length,
    );
  }

  /// 运行完整基准测试
  static Future<void> runFullBenchmark() async {
    debugPrint('========================================');
    debugPrint('📊 分页性能基准测试');
    debugPrint('========================================');

    final screenSize = const Size(1080, 1920);
    final padding = const EdgeInsets.all(20);

    for (final charCount in [10000, 50000, 100000, 300000]) {
      debugPrint('\n--- 测试: $charCount 字符 ---');

      final text = generateTestText(charCount);

      try {
        // 测试同步分页器（字符宽度缓存）
        final syncResult = await testSyncPaginator(
          text: text,
          screenSize: screenSize,
          fontSize: 18,
          lineSpacing: 1.8,
          padding: padding,
        );
        syncResult.print();

        // 测试新版分页器（二分查找）
        final optimizedResult = await testOptimizedPaginator(
          text: text,
          screenSize: screenSize,
          fontSize: 18,
          lineSpacing: 1.8,
          padding: padding,
        );
        optimizedResult.print();

        // 对于小文件，测试旧版分页器对比
        if (charCount <= 50000) {
          final oldResult = await testOldPaginator(
            text: text,
            screenSize: screenSize,
            fontSize: 18,
            lineSpacing: 1.8,
            padding: padding,
          );
          oldResult.print();

          // 计算性能提升
          final improvement =
              oldResult.elapsedMs / optimizedResult.elapsedMs;
          debugPrint('🚀 性能提升: ${improvement.toStringAsFixed(1)}x');
        }
      } catch (e) {
        debugPrint('❌ 测试失败: $e');
      }
    }

    debugPrint('\n========================================');
    debugPrint('✅ 基准测试完成');
    debugPrint('========================================');
  }
}

/// 基准测试结果
class BenchmarkResult {
  final String method;
  final int elapsedMs;
  final int pageCount;
  final int charCount;

  const BenchmarkResult({
    required this.method,
    required this.elapsedMs,
    required this.pageCount,
    required this.charCount,
  });

  double get charsPerSecond => (charCount / elapsedMs * 1000);
  double get msPerPage => elapsedMs / pageCount;

  void print() {
    debugPrint('方法: $method');
    debugPrint('  耗时: ${elapsedMs}ms');
    debugPrint('  页数: $pageCount');
    debugPrint('  速度: ${charsPerSecond.toStringAsFixed(0)} 字符/秒');
    debugPrint('  每页: ${msPerPage.toStringAsFixed(1)}ms');
  }
}
