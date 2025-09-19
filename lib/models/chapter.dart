class Chapter {
  final int? id; // 添加id字段
  final String title;
  int startPage; // Changed to non-final to allow updating after pagination
  final int endPage;
  final int level; // 章节层级，0=一级章节，等等
  final String? contentFileName; // Added for EPUB chapter mapping
  final String? anchor; // Added for EPUB chapter mapping
  final String? href; // 添加href字段用于EPUB
  final int order; // 添加order字段
  final List<Chapter> subChapters; // 子章节
  final bool isTableOfContents; // 是否为目录页

  Chapter({
    this.id,
    required this.title,
    required this.startPage,
    this.endPage = 0,
    this.level = 0,
    this.contentFileName,
    this.anchor,
    this.href,
    this.order = 0,
    this.subChapters = const [],
    this.isTableOfContents = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startPage': startPage,
      'endPage': endPage,
      'level': level,
      'contentFileName': contentFileName,
      'anchor': anchor,
      'href': href,
      'order': order,
      'subChapters': subChapters.map((chapter) => chapter.toMap()).toList(),
      'isTableOfContents': isTableOfContents,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'],
      title: map['title'] ?? '',
      startPage: map['startPage'] ?? 0,
      endPage: map['endPage'] ?? 0,
      level: map['level'] ?? 0,
      contentFileName: map['contentFileName'],
      anchor: map['anchor'],
      href: map['href'],
      order: map['order'] ?? 0,
      subChapters:
          (map['subChapters'] as List<dynamic>?)
              ?.map(
                (chapter) => Chapter.fromMap(chapter as Map<String, dynamic>),
              )
              .toList() ??
          [],
      isTableOfContents: map['isTableOfContents'] ?? false,
    );
  }

  // 检查是否可能是目录章节
  bool get isPossibleTableOfContents {
    return title.toLowerCase().contains('目录') ||
        title.toLowerCase().contains('contents') ||
        title.toLowerCase().contains('table of contents') ||
        title.toLowerCase().contains('索引') ||
        title == 'Contents' ||
        title == '目录';
  }

  // 检查是否是主要章节（第一章、第二章等）
  bool get isMainChapter {
    final chapterPatterns = [
      RegExp(r'^第[一二三四五六七八九十\d]+章'),
      RegExp(r'^Chapter\s+\d+', caseSensitive: false),
      RegExp(r'^\d+\.'),
      RegExp(r'^[一二三四五六七八九十]+、'),
    ];

    return chapterPatterns.any((pattern) => pattern.hasMatch(title));
  }

  // 检查是否是前言、序言等
  bool get isPreface {
    final prefacePatterns = [
      '前言',
      '序言',
      '自序',
      '序',
      'preface',
      'foreword',
      'introduction',
    ];

    return prefacePatterns.any(
      (pattern) => title.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  // 检查是否是后记、跋等
  bool get isEpilogue {
    final epiloguePatterns = [
      '后记',
      '跋',
      '结语',
      '结束语',
      'epilogue',
      'afterword',
      'conclusion',
    ];

    return epiloguePatterns.any(
      (pattern) => title.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  // 创建副本的方法
  Chapter copyWith({
    int? id,
    String? title,
    int? startPage,
    int? endPage,
    int? level,
    String? contentFileName,
    String? anchor,
    String? href,
    int? order,
    List<Chapter>? subChapters,
    bool? isTableOfContents,
  }) {
    return Chapter(
      id: id ?? this.id,
      title: title ?? this.title,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      level: level ?? this.level,
      contentFileName: contentFileName ?? this.contentFileName,
      anchor: anchor ?? this.anchor,
      href: href ?? this.href,
      order: order ?? this.order,
      subChapters: subChapters ?? this.subChapters,
      isTableOfContents: isTableOfContents ?? this.isTableOfContents,
    );
  }

  @override
  String toString() {
    return 'Chapter{title: $title, startPage: $startPage, endPage: $endPage, level: $level, subChapters: ${subChapters.length}}';
  }
}
