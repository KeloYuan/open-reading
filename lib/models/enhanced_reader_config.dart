import 'package:flutter/material.dart';

/// 🎯 增强的阅读器配置
///
/// 包含所有可调配置项
class EnhancedReaderConfig {
  // ==================== 文字配置 ====================

  /// 字体路径
  final String textFont;

  /// 粗体程度 (0:正常, 1:加粗, 2:细体)
  final int textBold;

  /// 字体大小
  final int textSize;

  /// 字间距
  final double letterSpacing;

  /// 行距（额外）
  final int lineSpacingExtra;

  /// 段落间距
  final int paragraphSpacing;

  /// 段落缩进字符（如"　　"）
  final String paragraphIndent;

  // ==================== 对齐配置 ====================

  /// 两端对齐
  final bool textFullJustify;

  /// 底部对齐
  final bool textBottomJustify;

  // ==================== 标题配置 ====================

  /// 标题模式 (0:居左, 1:居中, 2:隐藏)
  final int titleMode;

  /// 标题大小（相对于正文的增量）
  final int titleSize;

  /// 标题上间距
  final int titleTopSpacing;

  /// 标题下间距
  final int titleBottomSpacing;

  // ==================== 页边距配置 ====================

  /// 主内容区域边距
  final int paddingLeft;
  final int paddingRight;
  final int paddingTop;
  final int paddingBottom;

  /// 页眉边距
  final int headerPaddingLeft;
  final int headerPaddingRight;
  final int headerPaddingTop;
  final int headerPaddingBottom;

  /// 页脚边距
  final int footerPaddingLeft;
  final int footerPaddingRight;
  final int footerPaddingTop;
  final int footerPaddingBottom;

  // ==================== 显示配置 ====================

  /// 显示页眉分割线
  final bool showHeaderLine;

  /// 显示页脚分割线
  final bool showFooterLine;

  /// 下划线
  final bool underline;

  /// 背景透明度 (0-255)
  final int bgAlpha;

  // ==================== 翻页动画配置 ====================

  /// 翻页动画类型
  final PageAnimType pageAnim;

  // ==================== 其他配置 ====================

  /// 隐藏状态栏
  final bool hideStatusBar;

  /// 隐藏导航栏
  final bool hideNavigationBar;

  /// 使用中文排版
  final bool useZhLayout;

  /// 自动阅读速度 (1-999)
  final int autoReadSpeed;

  const EnhancedReaderConfig({
    // 文字配置
    this.textFont = '',
    this.textBold = 0,
    this.textSize = 18,
    this.letterSpacing = 0.2,
    this.lineSpacingExtra = 8,
    this.paragraphSpacing = 8,
    this.paragraphIndent = '　　',

    // 对齐配置
    this.textFullJustify = true,
    this.textBottomJustify = true,

    // 标题配置
    this.titleMode = 0,
    this.titleSize = 2,
    this.titleTopSpacing = 0,
    this.titleBottomSpacing = 0,

    // 主内容边距
    this.paddingLeft = 20,
    this.paddingRight = 20,
    this.paddingTop = 60,
    this.paddingBottom = 60,

    // 页眉边距
    this.headerPaddingLeft = 20,
    this.headerPaddingRight = 20,
    this.headerPaddingTop = 10,
    this.headerPaddingBottom = 10,

    // 页脚边距
    this.footerPaddingLeft = 20,
    this.footerPaddingRight = 20,
    this.footerPaddingTop = 10,
    this.footerPaddingBottom = 10,

    // 显示配置
    this.showHeaderLine = false,
    this.showFooterLine = false,
    this.underline = false,
    this.bgAlpha = 255,

    // 翻页动画
    this.pageAnim = PageAnimType.cover,

    // 其他
    this.hideStatusBar = false,
    this.hideNavigationBar = false,
    this.useZhLayout = true,
    this.autoReadSpeed = 10,
  });

  /// 复制并修改配置
  EnhancedReaderConfig copyWith({
    String? textFont,
    int? textBold,
    int? textSize,
    double? letterSpacing,
    int? lineSpacingExtra,
    int? paragraphSpacing,
    String? paragraphIndent,
    bool? textFullJustify,
    bool? textBottomJustify,
    int? titleMode,
    int? titleSize,
    int? titleTopSpacing,
    int? titleBottomSpacing,
    int? paddingLeft,
    int? paddingRight,
    int? paddingTop,
    int? paddingBottom,
    int? headerPaddingLeft,
    int? headerPaddingRight,
    int? headerPaddingTop,
    int? headerPaddingBottom,
    int? footerPaddingLeft,
    int? footerPaddingRight,
    int? footerPaddingTop,
    int? footerPaddingBottom,
    bool? showHeaderLine,
    bool? showFooterLine,
    bool? underline,
    int? bgAlpha,
    PageAnimType? pageAnim,
    bool? hideStatusBar,
    bool? hideNavigationBar,
    bool? useZhLayout,
    int? autoReadSpeed,
  }) {
    return EnhancedReaderConfig(
      textFont: textFont ?? this.textFont,
      textBold: textBold ?? this.textBold,
      textSize: textSize ?? this.textSize,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineSpacingExtra: lineSpacingExtra ?? this.lineSpacingExtra,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      textFullJustify: textFullJustify ?? this.textFullJustify,
      textBottomJustify: textBottomJustify ?? this.textBottomJustify,
      titleMode: titleMode ?? this.titleMode,
      titleSize: titleSize ?? this.titleSize,
      titleTopSpacing: titleTopSpacing ?? this.titleTopSpacing,
      titleBottomSpacing: titleBottomSpacing ?? this.titleBottomSpacing,
      paddingLeft: paddingLeft ?? this.paddingLeft,
      paddingRight: paddingRight ?? this.paddingRight,
      paddingTop: paddingTop ?? this.paddingTop,
      paddingBottom: paddingBottom ?? this.paddingBottom,
      headerPaddingLeft: headerPaddingLeft ?? this.headerPaddingLeft,
      headerPaddingRight: headerPaddingRight ?? this.headerPaddingRight,
      headerPaddingTop: headerPaddingTop ?? this.headerPaddingTop,
      headerPaddingBottom: headerPaddingBottom ?? this.headerPaddingBottom,
      footerPaddingLeft: footerPaddingLeft ?? this.footerPaddingLeft,
      footerPaddingRight: footerPaddingRight ?? this.footerPaddingRight,
      footerPaddingTop: footerPaddingTop ?? this.footerPaddingTop,
      footerPaddingBottom: footerPaddingBottom ?? this.footerPaddingBottom,
      showHeaderLine: showHeaderLine ?? this.showHeaderLine,
      showFooterLine: showFooterLine ?? this.showFooterLine,
      underline: underline ?? this.underline,
      bgAlpha: bgAlpha ?? this.bgAlpha,
      pageAnim: pageAnim ?? this.pageAnim,
      hideStatusBar: hideStatusBar ?? this.hideStatusBar,
      hideNavigationBar: hideNavigationBar ?? this.hideNavigationBar,
      useZhLayout: useZhLayout ?? this.useZhLayout,
      autoReadSpeed: autoReadSpeed ?? this.autoReadSpeed,
    );
  }

  /// 是否标题居中
  bool get isMiddleTitle => titleMode == 1;

  /// 是否隐藏标题
  bool get isTitleHidden => titleMode == 2;

  /// 获取实际的段落缩进字符数
  int get paragraphIndentLength => paragraphIndent.length;

  /// 获取EdgeInsets格式的padding
  EdgeInsets get edgeInsetsPadding => EdgeInsets.only(
        left: paddingLeft.toDouble(),
        right: paddingRight.toDouble(),
        top: paddingTop.toDouble(),
        bottom: paddingBottom.toDouble(),
      );

  /// 获取行距倍数（legado的lineSpacingExtra / 10）
  double get lineSpacingMultiplier => 1.0 + (lineSpacingExtra / 10.0);

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'textFont': textFont,
      'textBold': textBold,
      'textSize': textSize,
      'letterSpacing': letterSpacing,
      'lineSpacingExtra': lineSpacingExtra,
      'paragraphSpacing': paragraphSpacing,
      'paragraphIndent': paragraphIndent,
      'textFullJustify': textFullJustify,
      'textBottomJustify': textBottomJustify,
      'titleMode': titleMode,
      'titleSize': titleSize,
      'titleTopSpacing': titleTopSpacing,
      'titleBottomSpacing': titleBottomSpacing,
      'paddingLeft': paddingLeft,
      'paddingRight': paddingRight,
      'paddingTop': paddingTop,
      'paddingBottom': paddingBottom,
      'headerPaddingLeft': headerPaddingLeft,
      'headerPaddingRight': headerPaddingRight,
      'headerPaddingTop': headerPaddingTop,
      'headerPaddingBottom': headerPaddingBottom,
      'footerPaddingLeft': footerPaddingLeft,
      'footerPaddingRight': footerPaddingRight,
      'footerPaddingTop': footerPaddingTop,
      'footerPaddingBottom': footerPaddingBottom,
      'showHeaderLine': showHeaderLine,
      'showFooterLine': showFooterLine,
      'underline': underline,
      'bgAlpha': bgAlpha,
      'pageAnim': pageAnim.index,
      'hideStatusBar': hideStatusBar,
      'hideNavigationBar': hideNavigationBar,
      'useZhLayout': useZhLayout,
      'autoReadSpeed': autoReadSpeed,
    };
  }

  /// 从JSON创建
  factory EnhancedReaderConfig.fromJson(Map<String, dynamic> json) {
    return EnhancedReaderConfig(
      textFont: json['textFont'] as String? ?? '',
      textBold: json['textBold'] as int? ?? 0,
      textSize: json['textSize'] as int? ?? 18,
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0.2,
      lineSpacingExtra: json['lineSpacingExtra'] as int? ?? 8,
      paragraphSpacing: json['paragraphSpacing'] as int? ?? 8,
      paragraphIndent: json['paragraphIndent'] as String? ?? '　　',
      textFullJustify: json['textFullJustify'] as bool? ?? true,
      textBottomJustify: json['textBottomJustify'] as bool? ?? true,
      titleMode: json['titleMode'] as int? ?? 0,
      titleSize: json['titleSize'] as int? ?? 2,
      titleTopSpacing: json['titleTopSpacing'] as int? ?? 0,
      titleBottomSpacing: json['titleBottomSpacing'] as int? ?? 0,
      paddingLeft: json['paddingLeft'] as int? ?? 20,
      paddingRight: json['paddingRight'] as int? ?? 20,
      paddingTop: json['paddingTop'] as int? ?? 60,
      paddingBottom: json['paddingBottom'] as int? ?? 60,
      headerPaddingLeft: json['headerPaddingLeft'] as int? ?? 20,
      headerPaddingRight: json['headerPaddingRight'] as int? ?? 20,
      headerPaddingTop: json['headerPaddingTop'] as int? ?? 10,
      headerPaddingBottom: json['headerPaddingBottom'] as int? ?? 10,
      footerPaddingLeft: json['footerPaddingLeft'] as int? ?? 20,
      footerPaddingRight: json['footerPaddingRight'] as int? ?? 20,
      footerPaddingTop: json['footerPaddingTop'] as int? ?? 10,
      footerPaddingBottom: json['footerPaddingBottom'] as int? ?? 10,
      showHeaderLine: json['showHeaderLine'] as bool? ?? false,
      showFooterLine: json['showFooterLine'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      bgAlpha: json['bgAlpha'] as int? ?? 255,
      pageAnim: PageAnimType.values[json['pageAnim'] as int? ?? 0],
      hideStatusBar: json['hideStatusBar'] as bool? ?? false,
      hideNavigationBar: json['hideNavigationBar'] as bool? ?? false,
      useZhLayout: json['useZhLayout'] as bool? ?? true,
      autoReadSpeed: json['autoReadSpeed'] as int? ?? 10,
    );
  }
}

/// 翻页动画类型（完全按照legado的PageAnim）
enum PageAnimType {
  cover, // 0: 覆盖翻页
  slide, // 1: 滑动翻页
  simulation, // 2: 仿真翻页
  scroll, // 3: 滚动翻页
  none, // 4: 无动画
}

extension PageAnimTypeExtension on PageAnimType {
  String get displayName {
    switch (this) {
      case PageAnimType.cover:
        return '覆盖翻页';
      case PageAnimType.slide:
        return '滑动翻页';
      case PageAnimType.simulation:
        return '仿真翻页';
      case PageAnimType.scroll:
        return '滚动翻页';
      case PageAnimType.none:
        return '无动画';
    }
  }
}
