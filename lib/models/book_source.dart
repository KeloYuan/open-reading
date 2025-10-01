import 'package:flutter/material.dart';

/// 书源数据模型
/// 高级书源数据模型，支持在线书籍获取和管理
class BookSource {
  /// 书源唯一标识符
  final String id;

  /// 书源名称
  final String bookSourceName;

  /// 书源分组
  final String bookSourceGroup;

  /// 书源注释说明
  final String bookSourceComment;

  /// 书源类型（0: 小说, 1: 漫画, 2: 有声书）
  final int bookSourceType;

  /// 书源URL
  final String bookSourceUrl;

  /// 版本号
  final int bookSourceVersion;

  /// 是否启用
  final bool enabled;

  /// 是否启用发现
  final bool enabledExplore;

  /// 最后更新时间
  final int lastUpdateTime;

  /// 权重（用于排序）
  final int weight;

  /// 搜索规则
  final RuleSearch? ruleSearch;

  /// 发现规则
  final RuleExplore? ruleExplore;

  /// 书籍信息规则
  final RuleBookInfo? ruleBookInfo;

  /// 目录规则
  final RuleToc? ruleToc;

  /// 正文规则
  final RuleContent? ruleContent;

  /// 自定义变量
  final Map<String, String> variableMap;

  /// HTTP配置
  final Map<String, String> httpConfig;

  /// 请求头
  final Map<String, String> header;

  /// 登录URL
  final String? loginUrl;

  /// 登录用户界面
  final String? loginUi;

  /// 响应时间（毫秒）
  final int respondTime;

  const BookSource({
    required this.id,
    required this.bookSourceName,
    required this.bookSourceGroup,
    required this.bookSourceComment,
    required this.bookSourceType,
    required this.bookSourceUrl,
    required this.bookSourceVersion,
    required this.enabled,
    required this.enabledExplore,
    required this.lastUpdateTime,
    required this.weight,
    this.ruleSearch,
    this.ruleExplore,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
    this.variableMap = const {},
    this.httpConfig = const {},
    this.header = const {},
    this.loginUrl,
    this.loginUi,
    this.respondTime = 180000,
  });

  /// 工厂方法：从JSON创建书源
  factory BookSource.fromJson(Map<String, dynamic> json) {
    return BookSource(
      id: json['bookSourceUrl'] ?? '', // 使用URL作为ID
      bookSourceName: json['bookSourceName'] ?? '',
      bookSourceGroup: json['bookSourceGroup'] ?? '',
      bookSourceComment: json['bookSourceComment'] ?? '',
      bookSourceType: json['bookSourceType'] ?? 0,
      bookSourceUrl: json['bookSourceUrl'] ?? '',
      bookSourceVersion: json['bookSourceVersion'] ?? 1,
      enabled: json['enabled'] ?? true,
      enabledExplore: json['enabledExplore'] ?? true,
      lastUpdateTime:
          json['lastUpdateTime'] ?? DateTime.now().millisecondsSinceEpoch,
      weight: json['weight'] ?? 0,
      ruleSearch: json['ruleSearch'] != null
          ? RuleSearch.fromJson(json['ruleSearch'])
          : null,
      ruleExplore: json['ruleExplore'] != null
          ? RuleExplore.fromJson(json['ruleExplore'])
          : null,
      ruleBookInfo: json['ruleBookInfo'] != null
          ? RuleBookInfo.fromJson(json['ruleBookInfo'])
          : null,
      ruleToc: json['ruleToc'] != null
          ? RuleToc.fromJson(json['ruleToc'])
          : null,
      ruleContent: json['ruleContent'] != null
          ? RuleContent.fromJson(json['ruleContent'])
          : null,
      variableMap: Map<String, String>.from(json['variableMap'] ?? {}),
      httpConfig: Map<String, String>.from(json['httpConfig'] ?? {}),
      header: Map<String, String>.from(json['header'] ?? {}),
      loginUrl: json['loginUrl'],
      loginUi: json['loginUi'],
      respondTime: json['respondTime'] ?? 180000,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'bookSourceName': bookSourceName,
      'bookSourceGroup': bookSourceGroup,
      'bookSourceComment': bookSourceComment,
      'bookSourceType': bookSourceType,
      'bookSourceUrl': bookSourceUrl,
      'bookSourceVersion': bookSourceVersion,
      'enabled': enabled,
      'enabledExplore': enabledExplore,
      'lastUpdateTime': lastUpdateTime,
      'weight': weight,
      'ruleSearch': ruleSearch?.toJson(),
      'ruleExplore': ruleExplore?.toJson(),
      'ruleBookInfo': ruleBookInfo?.toJson(),
      'ruleToc': ruleToc?.toJson(),
      'ruleContent': ruleContent?.toJson(),
      'variableMap': variableMap,
      'httpConfig': httpConfig,
      'header': header,
      'loginUrl': loginUrl,
      'loginUi': loginUi,
      'respondTime': respondTime,
    };
  }

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_source_name': bookSourceName,
      'book_source_group': bookSourceGroup,
      'book_source_comment': bookSourceComment,
      'book_source_type': bookSourceType,
      'book_source_url': bookSourceUrl,
      'book_source_version': bookSourceVersion,
      'enabled': enabled ? 1 : 0,
      'enabled_explore': enabledExplore ? 1 : 0,
      'last_update_time': lastUpdateTime,
      'weight': weight,
      'rule_search': ruleSearch?.toJson(),
      'rule_explore': ruleExplore?.toJson(),
      'rule_book_info': ruleBookInfo?.toJson(),
      'rule_toc': ruleToc?.toJson(),
      'rule_content': ruleContent?.toJson(),
      'variable_map': variableMap,
      'http_config': httpConfig,
      'header': header,
      'login_url': loginUrl,
      'login_ui': loginUi,
      'respond_time': respondTime,
    };
  }

  /// 从数据库Map创建实例
  factory BookSource.fromMap(Map<String, dynamic> map) {
    return BookSource(
      id: map['id'] ?? '',
      bookSourceName: map['book_source_name'] ?? '',
      bookSourceGroup: map['book_source_group'] ?? '',
      bookSourceComment: map['book_source_comment'] ?? '',
      bookSourceType: map['book_source_type'] ?? 0,
      bookSourceUrl: map['book_source_url'] ?? '',
      bookSourceVersion: map['book_source_version'] ?? 1,
      enabled: (map['enabled'] ?? 1) == 1,
      enabledExplore: (map['enabled_explore'] ?? 1) == 1,
      lastUpdateTime:
          map['last_update_time'] ?? DateTime.now().millisecondsSinceEpoch,
      weight: map['weight'] ?? 0,
      ruleSearch: map['rule_search'] != null
          ? RuleSearch.fromJson(Map<String, dynamic>.from(map['rule_search']))
          : null,
      ruleExplore: map['rule_explore'] != null
          ? RuleExplore.fromJson(Map<String, dynamic>.from(map['rule_explore']))
          : null,
      ruleBookInfo: map['rule_book_info'] != null
          ? RuleBookInfo.fromJson(
              Map<String, dynamic>.from(map['rule_book_info']),
            )
          : null,
      ruleToc: map['rule_toc'] != null
          ? RuleToc.fromJson(Map<String, dynamic>.from(map['rule_toc']))
          : null,
      ruleContent: map['rule_content'] != null
          ? RuleContent.fromJson(Map<String, dynamic>.from(map['rule_content']))
          : null,
      variableMap: Map<String, String>.from(map['variable_map'] ?? {}),
      httpConfig: Map<String, String>.from(map['http_config'] ?? {}),
      header: Map<String, String>.from(map['header'] ?? {}),
      loginUrl: map['login_url'],
      loginUi: map['login_ui'],
      respondTime: map['respond_time'] ?? 180000,
    );
  }

  /// 获取书源类型名称
  String get typeName {
    switch (bookSourceType) {
      case 0:
        return '小说';
      case 1:
        return '漫画';
      case 2:
        return '有声书';
      default:
        return '未知';
    }
  }

  /// 获取书源图标
  IconData get typeIcon {
    switch (bookSourceType) {
      case 0:
        return Icons.book;
      case 1:
        return Icons.photo_library;
      case 2:
        return Icons.audiotrack;
      default:
        return Icons.help_outline;
    }
  }

  /// 是否有搜索功能
  bool get hasSearch => ruleSearch != null && ruleSearch!.isValid;

  /// 是否有发现功能
  bool get hasExplore => ruleExplore != null && ruleExplore!.isValid;

  /// 创建副本
  BookSource copyWith({
    String? id,
    String? bookSourceName,
    String? bookSourceGroup,
    String? bookSourceComment,
    int? bookSourceType,
    String? bookSourceUrl,
    int? bookSourceVersion,
    bool? enabled,
    bool? enabledExplore,
    int? lastUpdateTime,
    int? weight,
    RuleSearch? ruleSearch,
    RuleExplore? ruleExplore,
    RuleBookInfo? ruleBookInfo,
    RuleToc? ruleToc,
    RuleContent? ruleContent,
    Map<String, String>? variableMap,
    Map<String, String>? httpConfig,
    Map<String, String>? header,
    String? loginUrl,
    String? loginUi,
    int? respondTime,
  }) {
    return BookSource(
      id: id ?? this.id,
      bookSourceName: bookSourceName ?? this.bookSourceName,
      bookSourceGroup: bookSourceGroup ?? this.bookSourceGroup,
      bookSourceComment: bookSourceComment ?? this.bookSourceComment,
      bookSourceType: bookSourceType ?? this.bookSourceType,
      bookSourceUrl: bookSourceUrl ?? this.bookSourceUrl,
      bookSourceVersion: bookSourceVersion ?? this.bookSourceVersion,
      enabled: enabled ?? this.enabled,
      enabledExplore: enabledExplore ?? this.enabledExplore,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      weight: weight ?? this.weight,
      ruleSearch: ruleSearch ?? this.ruleSearch,
      ruleExplore: ruleExplore ?? this.ruleExplore,
      ruleBookInfo: ruleBookInfo ?? this.ruleBookInfo,
      ruleToc: ruleToc ?? this.ruleToc,
      ruleContent: ruleContent ?? this.ruleContent,
      variableMap: variableMap ?? this.variableMap,
      httpConfig: httpConfig ?? this.httpConfig,
      header: header ?? this.header,
      loginUrl: loginUrl ?? this.loginUrl,
      loginUi: loginUi ?? this.loginUi,
      respondTime: respondTime ?? this.respondTime,
    );
  }

  @override
  String toString() {
    return 'BookSource{name: $bookSourceName, url: $bookSourceUrl, type: $typeName, enabled: $enabled}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookSource && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 搜索规则
class RuleSearch {
  /// 搜索地址
  final String url;

  /// 搜索关键字编码
  final String charset;

  /// 书籍列表规则
  final String bookList;

  /// 书名规则
  final String name;

  /// 作者规则
  final String author;

  /// 分类规则
  final String kind;

  /// 最新章节规则
  final String lastChapter;

  /// 简介规则
  final String intro;

  /// 封面规则
  final String coverUrl;

  /// 书籍URL规则
  final String bookUrl;

  const RuleSearch({
    required this.url,
    this.charset = 'UTF-8',
    required this.bookList,
    required this.name,
    required this.author,
    this.kind = '',
    this.lastChapter = '',
    this.intro = '',
    this.coverUrl = '',
    required this.bookUrl,
  });

  factory RuleSearch.fromJson(Map<String, dynamic> json) {
    return RuleSearch(
      url: json['url'] ?? '',
      charset: json['charset'] ?? 'UTF-8',
      bookList: json['bookList'] ?? '',
      name: json['name'] ?? '',
      author: json['author'] ?? '',
      kind: json['kind'] ?? '',
      lastChapter: json['lastChapter'] ?? '',
      intro: json['intro'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      bookUrl: json['bookUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'charset': charset,
      'bookList': bookList,
      'name': name,
      'author': author,
      'kind': kind,
      'lastChapter': lastChapter,
      'intro': intro,
      'coverUrl': coverUrl,
      'bookUrl': bookUrl,
    };
  }

  /// 规则是否有效
  bool get isValid => url.isNotEmpty && bookList.isNotEmpty && name.isNotEmpty;
}

/// 发现规则
class RuleExplore {
  /// 发现地址
  final String url;

  /// 书籍列表规则
  final String bookList;

  /// 书名规则
  final String name;

  /// 作者规则
  final String author;

  /// 分类规则
  final String kind;

  /// 最新章节规则
  final String lastChapter;

  /// 简介规则
  final String intro;

  /// 封面规则
  final String coverUrl;

  /// 书籍URL规则
  final String bookUrl;

  const RuleExplore({
    required this.url,
    required this.bookList,
    required this.name,
    required this.author,
    this.kind = '',
    this.lastChapter = '',
    this.intro = '',
    this.coverUrl = '',
    required this.bookUrl,
  });

  factory RuleExplore.fromJson(Map<String, dynamic> json) {
    return RuleExplore(
      url: json['url'] ?? '',
      bookList: json['bookList'] ?? '',
      name: json['name'] ?? '',
      author: json['author'] ?? '',
      kind: json['kind'] ?? '',
      lastChapter: json['lastChapter'] ?? '',
      intro: json['intro'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      bookUrl: json['bookUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'bookList': bookList,
      'name': name,
      'author': author,
      'kind': kind,
      'lastChapter': lastChapter,
      'intro': intro,
      'coverUrl': coverUrl,
      'bookUrl': bookUrl,
    };
  }

  /// 规则是否有效
  bool get isValid => url.isNotEmpty && bookList.isNotEmpty && name.isNotEmpty;
}

/// 书籍信息规则
class RuleBookInfo {
  /// 初始化地址
  final String init;

  /// 书名规则
  final String name;

  /// 作者规则
  final String author;

  /// 分类规则
  final String kind;

  /// 最新章节规则
  final String lastChapter;

  /// 简介规则
  final String intro;

  /// 封面规则
  final String coverUrl;

  /// 目录URL规则
  final String tocUrl;

  /// 字数规则
  final String wordCount;

  const RuleBookInfo({
    this.init = '',
    required this.name,
    required this.author,
    this.kind = '',
    this.lastChapter = '',
    this.intro = '',
    this.coverUrl = '',
    this.tocUrl = '',
    this.wordCount = '',
  });

  factory RuleBookInfo.fromJson(Map<String, dynamic> json) {
    return RuleBookInfo(
      init: json['init'] ?? '',
      name: json['name'] ?? '',
      author: json['author'] ?? '',
      kind: json['kind'] ?? '',
      lastChapter: json['lastChapter'] ?? '',
      intro: json['intro'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      tocUrl: json['tocUrl'] ?? '',
      wordCount: json['wordCount'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'init': init,
      'name': name,
      'author': author,
      'kind': kind,
      'lastChapter': lastChapter,
      'intro': intro,
      'coverUrl': coverUrl,
      'tocUrl': tocUrl,
      'wordCount': wordCount,
    };
  }

  /// 规则是否有效
  bool get isValid => name.isNotEmpty && author.isNotEmpty;
}

/// 目录规则
class RuleToc {
  /// 章节列表规则
  final String chapterList;

  /// 章节名称规则
  final String chapterName;

  /// 章节URL规则
  final String chapterUrl;

  /// 是否是VIP章节规则
  final String isVip;

  /// 更新时间规则
  final String updateTime;

  const RuleToc({
    required this.chapterList,
    required this.chapterName,
    required this.chapterUrl,
    this.isVip = '',
    this.updateTime = '',
  });

  factory RuleToc.fromJson(Map<String, dynamic> json) {
    return RuleToc(
      chapterList: json['chapterList'] ?? '',
      chapterName: json['chapterName'] ?? '',
      chapterUrl: json['chapterUrl'] ?? '',
      isVip: json['isVip'] ?? '',
      updateTime: json['updateTime'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chapterList': chapterList,
      'chapterName': chapterName,
      'chapterUrl': chapterUrl,
      'isVip': isVip,
      'updateTime': updateTime,
    };
  }

  /// 规则是否有效
  bool get isValid =>
      chapterList.isNotEmpty && chapterName.isNotEmpty && chapterUrl.isNotEmpty;
}

/// 正文规则
class RuleContent {
  /// 正文规则
  final String content;

  /// 下一页URL规则
  final String nextUrl;

  /// 网页标题规则
  final String webJs;

  /// 图片样式规则
  final String imageStyle;

  /// 替换规则
  final String replaceRegex;

  const RuleContent({
    required this.content,
    this.nextUrl = '',
    this.webJs = '',
    this.imageStyle = '',
    this.replaceRegex = '',
  });

  factory RuleContent.fromJson(Map<String, dynamic> json) {
    return RuleContent(
      content: json['content'] ?? '',
      nextUrl: json['nextUrl'] ?? '',
      webJs: json['webJs'] ?? '',
      imageStyle: json['imageStyle'] ?? '',
      replaceRegex: json['replaceRegex'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'nextUrl': nextUrl,
      'webJs': webJs,
      'imageStyle': imageStyle,
      'replaceRegex': replaceRegex,
    };
  }

  /// 规则是否有效
  bool get isValid => content.isNotEmpty;
}
