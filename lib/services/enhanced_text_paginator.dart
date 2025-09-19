import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 增强的文本分页器
/// 根据屏幕尺寸和设备特性智能计算最佳分页参数
class EnhancedTextPaginator {
  static const double kDefaultFontSize = 16.0;
  static const double kDefaultLineHeight = 1.5;
  static const String kSampleText = '中国汉字测试样本文字内容显示效果检测分页算法';

  /// 计算适应屏幕的分页参数
  static PaginationParams calculateOptimalParams({
    required Size screenSize,
    required double fontSize,
    required double lineHeight,
    required EdgeInsets padding,
    required double statusBarHeight,
    required bool isLandscape,
    String? customSampleText,
  }) {
    // 根据屏幕尺寸确定设备类型
    final deviceType = _getDeviceType(screenSize);

    // 计算实际可用的文本区域
    final textArea = _calculateTextArea(
      screenSize: screenSize,
      padding: padding,
      statusBarHeight: statusBarHeight,
      deviceType: deviceType,
      isLandscape: isLandscape,
    );

    // 使用样本文字测量字符尺寸
    final charMetrics = _measureCharacterMetrics(
      fontSize: fontSize,
      lineHeight: lineHeight,
      sampleText: customSampleText ?? kSampleText,
      maxWidth: textArea.width,
    );

    // 计算每页字符数
    final charsPerLine = _calculateCharsPerLine(
      textWidth: textArea.width,
      charWidth: charMetrics.averageCharWidth,
      deviceType: deviceType,
    );

    final linesPerPage = _calculateLinesPerPage(
      textHeight: textArea.height,
      lineHeight: charMetrics.lineHeight,
      deviceType: deviceType,
    );

    final charsPerPage = charsPerLine * linesPerPage;

    debugPrint('📊 增强分页器: ${deviceType.name} ${isLandscape ? '横屏' : '竖屏'}');
    debugPrint(
      '📊 文本区域: ${textArea.width.toInt()}x${textArea.height.toInt()}px',
    );
    debugPrint(
      '📊 字符尺寸: ${charMetrics.averageCharWidth.toStringAsFixed(1)}px宽, ${charMetrics.lineHeight.toStringAsFixed(1)}px高',
    );
    debugPrint(
      '📊 分页参数: $charsPerLine字符/行, $linesPerPage行/页, $charsPerPage字符/页',
    );

    return PaginationParams(
      charsPerLine: charsPerLine,
      linesPerPage: linesPerPage,
      charsPerPage: charsPerPage,
      textArea: textArea,
      charMetrics: charMetrics,
      deviceType: deviceType,
    );
  }

  /// 获取设备类型
  static DeviceType _getDeviceType(Size screenSize) {
    final diagonal = math.sqrt(
      screenSize.width * screenSize.width +
          screenSize.height * screenSize.height,
    );

    if (diagonal > 1200) {
      return DeviceType.tablet;
    } else if (diagonal > 800) {
      return DeviceType.largeMobile;
    } else {
      return DeviceType.mobile;
    }
  }

  /// 计算文本显示区域
  static Size _calculateTextArea({
    required Size screenSize,
    required EdgeInsets padding,
    required double statusBarHeight,
    required DeviceType deviceType,
    required bool isLandscape,
  }) {
    // 根据设备类型调整预留空间
    double bottomReserve;
    double topReserve;

    switch (deviceType) {
      case DeviceType.tablet:
        bottomReserve = isLandscape ? 100.0 : 120.0;
        topReserve = isLandscape ? 60.0 : 80.0;
        break;
      case DeviceType.largeMobile:
        bottomReserve = isLandscape ? 80.0 : 100.0;
        topReserve = isLandscape ? 50.0 : 70.0;
        break;
      case DeviceType.mobile:
        bottomReserve = isLandscape ? 70.0 : 90.0;
        topReserve = isLandscape ? 40.0 : 60.0;
        break;
    }

    final width = screenSize.width - padding.horizontal;
    final height =
        screenSize.height -
        padding.vertical -
        statusBarHeight -
        topReserve -
        bottomReserve;

    return Size(width, height);
  }

  /// 测量字符尺寸
  static CharacterMetrics _measureCharacterMetrics({
    required double fontSize,
    required double lineHeight,
    required String sampleText,
    required double maxWidth,
  }) {
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      fontFamily: 'System',
    );

    final textPainter = TextPainter(
      text: TextSpan(text: sampleText, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify,
    );

    textPainter.layout(maxWidth: maxWidth);

    final averageCharWidth = textPainter.size.width / sampleText.length;
    final measuredLineHeight = textPainter.size.height;

    textPainter.dispose();

    return CharacterMetrics(
      averageCharWidth: averageCharWidth,
      lineHeight: measuredLineHeight,
    );
  }

  /// 计算每行字符数
  static int _calculateCharsPerLine({
    required double textWidth,
    required double charWidth,
    required DeviceType deviceType,
  }) {
    // 根据设备类型调整保守系数
    double conservativeFactor;
    switch (deviceType) {
      case DeviceType.tablet:
        conservativeFactor = 0.90; // 平板屏幕大，可以更激进
        break;
      case DeviceType.largeMobile:
        conservativeFactor = 0.85;
        break;
      case DeviceType.mobile:
        conservativeFactor = 0.80; // 小屏幕更保守
        break;
    }

    final rawCharsPerLine = textWidth / charWidth;
    final conservativeCharsPerLine = (rawCharsPerLine * conservativeFactor)
        .floor();

    // 确保最小值
    return math.max(conservativeCharsPerLine, 10);
  }

  /// 计算每页行数
  static int _calculateLinesPerPage({
    required double textHeight,
    required double lineHeight,
    required DeviceType deviceType,
  }) {
    // 根据设备类型调整保守系数
    double conservativeFactor;
    switch (deviceType) {
      case DeviceType.tablet:
        conservativeFactor = 0.92;
        break;
      case DeviceType.largeMobile:
        conservativeFactor = 0.88;
        break;
      case DeviceType.mobile:
        conservativeFactor = 0.85;
        break;
    }

    final rawLinesPerPage = textHeight / lineHeight;
    final conservativeLinesPerPage = (rawLinesPerPage * conservativeFactor)
        .floor();

    // 确保最小值
    return math.max(conservativeLinesPerPage, 3);
  }

  /// 自适应分页主方法
  static Future<List<String>> paginateText({
    required String text,
    required PaginationParams params,
  }) async {
    if (text.isEmpty) return [];

    return compute(_paginateInBackground, {
      'text': text,
      'charsPerPage': params.charsPerPage,
      'deviceType': params.deviceType.index,
    });
  }

  /// 后台分页处理
  static List<String> _paginateInBackground(Map<String, dynamic> args) {
    final String text = args['text'];
    final int charsPerPage = args['charsPerPage'];
    final DeviceType deviceType = DeviceType.values[args['deviceType']];

    final List<String> pages = [];
    int currentIndex = 0;
    int pageCount = 0;
    const int maxPages = 100000;

    while (currentIndex < text.length && pageCount < maxPages) {
      pageCount++;

      final remainingLength = text.length - currentIndex;

      if (remainingLength <= charsPerPage) {
        final remainingText = text.substring(currentIndex);
        if (remainingText.trim().isNotEmpty) {
          pages.add(remainingText);
        }
        break;
      }

      // 根据设备类型调整分页策略
      double pageSizeFactor;
      switch (deviceType) {
        case DeviceType.tablet:
          pageSizeFactor = 0.90; // 平板可以更激进
          break;
        case DeviceType.largeMobile:
          pageSizeFactor = 0.85;
          break;
        case DeviceType.mobile:
          pageSizeFactor = 0.80; // 小屏更保守
          break;
      }

      int suggestedEndIndex =
          currentIndex + (charsPerPage * pageSizeFactor).floor();
      suggestedEndIndex = math.min(suggestedEndIndex, text.length);

      int actualEndIndex = _findOptimalBreakPoint(
        text,
        currentIndex,
        suggestedEndIndex,
        deviceType,
      );

      if (actualEndIndex - currentIndex < charsPerPage * 0.3) {
        actualEndIndex = suggestedEndIndex;
      }

      final pageText = text.substring(currentIndex, actualEndIndex);
      if (pageText.trim().isNotEmpty) {
        pages.add(pageText);
      }

      currentIndex = actualEndIndex;

      if (actualEndIndex == currentIndex && currentIndex < text.length) {
        currentIndex++;
      }
    }

    if (kDebugMode) {
      debugPrint('📖 增强分页完成: ${pages.length}页, 设备类型: ${deviceType.name}');
    }

    return pages;
  }

  /// 寻找最佳断点
  static int _findOptimalBreakPoint(
    String text,
    int startIndex,
    int suggestedEndIndex,
    DeviceType deviceType,
  ) {
    suggestedEndIndex = math.min(suggestedEndIndex, text.length);

    if (suggestedEndIndex >= text.length) {
      return text.length;
    }

    // 根据设备类型调整搜索范围
    int searchRange;
    switch (deviceType) {
      case DeviceType.tablet:
        searchRange = 30; // 平板可以搜索更远
        break;
      case DeviceType.largeMobile:
        searchRange = 20;
        break;
      case DeviceType.mobile:
        searchRange = 15; // 小屏搜索范围小
        break;
    }

    searchRange = math.min(searchRange, suggestedEndIndex - startIndex - 1);
    int bestBreakPoint = suggestedEndIndex;

    if (suggestedEndIndex - startIndex > 50) {
      for (int i = 0; i < searchRange; i++) {
        int checkIndex = suggestedEndIndex - 1 - i;
        if (checkIndex <= startIndex) break;

        String char = text[checkIndex];

        // 优先级断点：段落分隔
        if (char == '\n' && i < searchRange ~/ 3) {
          bestBreakPoint = checkIndex + 1;
          break;
        }
        // 次优先级：句子结尾
        else if ((char == '。' || char == '！' || char == '？' || char == '.') &&
            i < searchRange ~/ 2) {
          bestBreakPoint = checkIndex + 1;
          break;
        }
        // 再次优先级：标点符号
        else if ((char == '，' || char == '；' || char == '：' || char == ',') &&
            i < searchRange * 2 ~/ 3) {
          bestBreakPoint = checkIndex + 1;
        }
      }
    }

    // 确保断点不会造成页面过小
    if (bestBreakPoint - startIndex < (suggestedEndIndex - startIndex) * 0.6) {
      bestBreakPoint = suggestedEndIndex;
    }

    return math.min(bestBreakPoint, text.length);
  }
}

/// 设备类型枚举
enum DeviceType { mobile, largeMobile, tablet }

extension DeviceTypeExtension on DeviceType {
  String get name {
    switch (this) {
      case DeviceType.mobile:
        return '手机';
      case DeviceType.largeMobile:
        return '大屏手机';
      case DeviceType.tablet:
        return '平板';
    }
  }
}

/// 字符测量结果
class CharacterMetrics {
  final double averageCharWidth;
  final double lineHeight;

  const CharacterMetrics({
    required this.averageCharWidth,
    required this.lineHeight,
  });
}

/// 分页参数
class PaginationParams {
  final int charsPerLine;
  final int linesPerPage;
  final int charsPerPage;
  final Size textArea;
  final CharacterMetrics charMetrics;
  final DeviceType deviceType;

  const PaginationParams({
    required this.charsPerLine,
    required this.linesPerPage,
    required this.charsPerPage,
    required this.textArea,
    required this.charMetrics,
    required this.deviceType,
  });
}
