import 'package:flutter/material.dart';
import 'ultra_precise_paginator.dart';

/// 分页器适配器
///
/// 将UltraPrecisePaginator适配到现有的阅读页面接口
/// 提供与原有分页器兼容的API，方便无缝替换
class UltraPaginatorAdapter {
  PaginationResult? _currentResult;
  int _currentPageIndex = 0;

  /// 是否已分页
  bool get isPaginated => _currentResult != null;

  /// 获取当前页面索引
  int get currentPageIndex => _currentPageIndex;

  /// 设置当前页面索引
  set currentPageIndex(int value) {
    if (_currentResult != null &&
        value >= 0 &&
        value < _currentResult!.pages.length) {
      _currentPageIndex = value;
    }
  }

  /// 获取总页数
  int get totalPages => _currentResult?.pages.length ?? 0;

  /// 获取每页最大行数
  int get maxLinesPerPage => _currentResult?.maxLinesPerPage ?? 0;

  /// 获取当前页面文本
  String getCurrentPageText() {
    if (_currentResult == null ||
        _currentPageIndex >= _currentResult!.pages.length) {
      return '';
    }
    return _currentResult!.pages[_currentPageIndex].rawText;
  }

  /// 获取当前页面的行列表
  List<String> getCurrentPageLines() {
    if (_currentResult == null ||
        _currentPageIndex >= _currentResult!.pages.length) {
      return [];
    }
    return _currentResult!.pages[_currentPageIndex].lines;
  }

  /// 获取指定页面的文本
  String getPageText(int pageIndex) {
    if (_currentResult == null ||
        pageIndex < 0 ||
        pageIndex >= _currentResult!.pages.length) {
      return '';
    }
    return _currentResult!.pages[pageIndex].rawText;
  }

  /// 获取指定页面的行列表
  List<String> getPageLines(int pageIndex) {
    if (_currentResult == null ||
        pageIndex < 0 ||
        pageIndex >= _currentResult!.pages.length) {
      return [];
    }
    return _currentResult!.pages[pageIndex].lines;
  }

  /// 初始化分页器
  Future<void> initialize({
    required Size screenSize,
    required double pixelRatio,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required EdgeInsets padding,
    required double statusBarHeight,
    int firstLineIndent = 2,
    String? fontFamily,
  }) async {
    await UltraPrecisePaginator.initialize(
      screenSize: screenSize,
      pixelRatio: pixelRatio,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      padding: padding,
      statusBarHeight: statusBarHeight,
      firstLineIndent: firstLineIndent,
      fontFamily: fontFamily,
    );
  }

  /// 执行分页
  Future<void> paginate({
    required String content,
    String? title,
    int initialPageIndex = 0,
  }) async {
    _currentResult = await UltraPrecisePaginator.paginate(
      content: content,
      title: title,
    );
    _currentPageIndex = initialPageIndex.clamp(0, totalPages - 1);
  }

  /// 翻到下一页
  bool nextPage() {
    if (_currentResult == null) return false;
    if (_currentPageIndex < _currentResult!.pages.length - 1) {
      _currentPageIndex++;
      return true;
    }
    return false;
  }

  /// 翻到上一页
  bool previousPage() {
    if (_currentResult == null) return false;
    if (_currentPageIndex > 0) {
      _currentPageIndex--;
      return true;
    }
    return false;
  }

  /// 跳转到指定页
  bool goToPage(int pageIndex) {
    if (_currentResult == null) return false;
    if (pageIndex >= 0 && pageIndex < _currentResult!.pages.length) {
      _currentPageIndex = pageIndex;
      return true;
    }
    return false;
  }

  /// 是否有下一页
  bool get hasNextPage {
    if (_currentResult == null) return false;
    return _currentPageIndex < _currentResult!.pages.length - 1;
  }

  /// 是否有上一页
  bool get hasPreviousPage {
    if (_currentResult == null) return false;
    return _currentPageIndex > 0;
  }

  /// 获取阅读进度（0.0 - 1.0）
  double get readProgress {
    if (_currentResult == null || _currentResult!.pages.isEmpty) return 0.0;
    return (_currentPageIndex + 1) / _currentResult!.pages.length;
  }

  /// 获取阅读进度文本
  String get readProgressText {
    if (_currentResult == null || _currentResult!.pages.isEmpty) return '0%';
    final progress = (readProgress * 100).toStringAsFixed(1);
    return '$progress%';
  }

  /// 获取页码文本
  String get pageNumberText {
    if (_currentResult == null || _currentResult!.pages.isEmpty) return '0/0';
    return '${_currentPageIndex + 1}/${_currentResult!.pages.length}';
  }

  /// 获取布局参数（用于调试）
  Map<String, dynamic> getLayoutParams() {
    return UltraPrecisePaginator.getLayoutParams();
  }

  /// 清除分页结果
  void clear() {
    _currentResult = null;
    _currentPageIndex = 0;
  }
}
