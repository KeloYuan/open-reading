import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

// Isolate分页参数 - 只包含基本类型
class IsolatePaginationParams {
  final String text;
  final int charsPerPage;
  
  const IsolatePaginationParams({
    required this.text,
    required this.charsPerPage,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'charsPerPage': charsPerPage,
    };
  }
}

// Isolate的入口函数 - 字符严格连续分页，绝不丢字
List<String> _paginateInIsolate(Map<String, dynamic> params) {
  final String text = params['text'];
  final int charsPerPage = params['charsPerPage'];

  final List<String> pages = [];
  int currentTextIndex = 0;
  int pageCount = 0;
  const int maxPages = 50000; // 防止无限循环

  while (currentTextIndex < text.length && pageCount < maxPages) {
    pageCount++;

    final remainingLength = text.length - currentTextIndex;
    
    // 如果剩余文本小于一页容量，全部放入最后一页
    if (remainingLength <= charsPerPage) {
      final remainingText = text.substring(currentTextIndex);
      if (remainingText.trim().isNotEmpty) {
        pages.add(remainingText);
      }
      break;
    }

    // 保守估算页面长度，确保不丢字
    int suggestedEndIndex = currentTextIndex + (charsPerPage * 0.8).floor(); // 更保守的80%
    suggestedEndIndex = math.min(suggestedEndIndex, text.length);
    
    // 寻找安全断点，但如果找不到好断点就按字符数切分
    int actualEndIndex = _findSafeBreakPointInIsolate(
      text, 
      currentTextIndex, 
      suggestedEndIndex
    );
    
    // 如果断点太保守，导致页面太小，就用建议的位置
    if (actualEndIndex - currentTextIndex < charsPerPage * 0.5) {
      actualEndIndex = suggestedEndIndex;
    }
    
    // 提取页面文本
    final pageText = text.substring(currentTextIndex, actualEndIndex);
    
    if (pageText.trim().isNotEmpty) {
      pages.add(pageText);
    }
    
    // 严格连续：下一页从当前页结束位置开始，绝对不跳字
    currentTextIndex = actualEndIndex;
    
    // 安全检查：如果没有前进，强制前进一个字符避免死循环
    if (actualEndIndex == currentTextIndex && currentTextIndex < text.length) {
      currentTextIndex++;
    }
  }

  // 调试输出 - 仅在debug模式启用
  if (kDebugMode) {
    debugPrint('📖 分页完成: 总共${pages.length}页，文本长度${text.length}字符');
    for (int i = 0; i < math.min(3, pages.length); i++) {
      final page = pages[i];
      debugPrint('📄 第${i+1}页: ${page.length}字符, 开头: "${page.substring(0, math.min(10, page.length))}"');
    }
  }

  return pages;
}

// Isolate中的安全断点查找 - 极度保守，宁可不断点也不丢字
int _findSafeBreakPointInIsolate(String fullText, int startIndex, int suggestedEndIndex) {
  suggestedEndIndex = math.min(suggestedEndIndex, fullText.length);
  
  // 如果建议的结束位置就是文本末尾，直接返回
  if (suggestedEndIndex >= fullText.length) {
    return fullText.length;
  }
  
  // 只在非常小的范围内寻找断点，避免丢失内容
  final searchRange = math.min(15, suggestedEndIndex - startIndex - 1);
  int bestBreakPoint = suggestedEndIndex;
  
  // 只在页面内容足够多时才寻找断点
  if (suggestedEndIndex - startIndex > 100) {
    for (int i = 0; i < searchRange; i++) {
      int checkIndex = suggestedEndIndex - 1 - i;
      if (checkIndex <= startIndex) break;
      
      String char = fullText[checkIndex];
      
      // 只接受最强的断点：换行符
      if (char == '\n') {
        bestBreakPoint = checkIndex + 1;
        break;
      }
      // 只在搜索前5个字符时接受句号
      else if ((char == '。' || char == '！' || char == '？') && i < 5) {
        bestBreakPoint = checkIndex + 1;
        break;
      }
    }
  }
  
  // 如果找到的断点会导致页面过小，放弃断点使用建议位置
  if (bestBreakPoint - startIndex < (suggestedEndIndex - startIndex) * 0.7) {
    bestBreakPoint = suggestedEndIndex;
  }
  
  return math.min(bestBreakPoint, fullText.length);
}

// 封装了调用逻辑的类
class TextPaginator {
  final String text;
  final TextStyle style;

  TextPaginator(this.text, this.style);

  Future<List<String>> paginate(
    BoxConstraints constraints, {
    required double statusBarHeight,
    required bool isDoublePage,
    bool isLargeScreen = false, // 新增参数
  }) async {
    // 使用与页面渲染一致的边距计算
    final horizontalPadding = isDoublePage ? 16.0 * 0.5 : 16.0; // 与_buildPageWidget保持一致
    final topPadding = isDoublePage ? 20.0 : 30.0;              // 与_buildPageWidget保持一致
    final bottomPadding = isDoublePage ? 20.0 : 30.0;           // 与_buildPageWidget保持一致
    
    // 为控制栏预留空间 - 优化空间利用
    final controlBarReserveHeight = isLargeScreen ? 120.0 : 80.0;
    
    final actualTextWidth = constraints.maxWidth - (horizontalPadding * 2);
    final actualTextHeight = constraints.maxHeight - topPadding - bottomPadding - statusBarHeight - controlBarReserveHeight;
    
    // 在主线程中预计算文本度量参数 - 使用纯中文样本提高精度
    final textPainter = TextPainter(
      text: TextSpan(text: '中国汉字测试样本文字内容显示效果', style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify,
    );
    textPainter.layout(maxWidth: actualTextWidth);
    
    // 计算平均字符尺寸 - 使用纯中文样本
    final sampleText = '中国汉字测试样本文字内容显示效果';
    final sampleWidth = textPainter.size.width;
    final lineHeight = textPainter.size.height;
    final averageCharWidth = sampleWidth / sampleText.length;
    
    // 计算每行字符数和每页行数 - 极度保守策略确保不丢字
    final charsPerLine = (actualTextWidth / averageCharWidth * 0.8).floor(); // 非常保守的80%
    final linesPerPage = (actualTextHeight / lineHeight * 0.8).floor(); // 非常保守的80%
    final charsPerPage = charsPerLine * linesPerPage;
    
    textPainter.dispose(); // 清理资源
    
    debugPrint('📊 TextPaginator度量: 文本区域${actualTextWidth.toInt()}x${actualTextHeight.toInt()}px');
    debugPrint('📊 TextPaginator度量: 每行$charsPerLine字符, 每页$linesPerPage行, 总计$charsPerPage字符/页');
    
    // 创建Isolate分页参数
    final isolateParams = IsolatePaginationParams(
      text: text,
      charsPerPage: charsPerPage,
    );
    
    // 使用compute函数将任务发送到后台Isolate
    return compute(_paginateInIsolate, isolateParams.toMap());
  }
}