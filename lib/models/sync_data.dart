/// WebDAV 同步数据模型
///
/// 定义所有同步相关的数据传输格式
///

/// 同步数据包装器
///
/// 所有同步 JSON 的通用格式
class SyncWrapper<T> {
  final int version;
  final String? deviceId;
  final String timestamp;
  final T data;

  SyncWrapper({
    required this.version,
    this.deviceId,
    required this.timestamp,
    required this.data,
  });

  /// 从 JSON 创建
  factory SyncWrapper.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) dataParser,
  ) {
    return SyncWrapper<T>(
      version: json['version'] as int? ?? 1,
      deviceId: json['device_id'] as String?,
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      data: dataParser(json['data'] ?? json),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson(dynamic Function(T) dataSerializer) {
    return {
      'version': version,
      if (deviceId != null) 'device_id': deviceId,
      'timestamp': timestamp,
      'data': dataSerializer(data),
    };
  }
}

/// 书籍同步数据（差异化字段）
class SyncBookData {
  final int? id;
  final String title;
  final String author;
  final String filePath;
  final String format;
  final int currentPage;
  final int totalPages;
  final int importDate;
  final String? contentHash;
  final String? coverImagePath;
  final String? updateTime;

  SyncBookData({
    this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.format,
    required this.currentPage,
    required this.totalPages,
    required this.importDate,
    this.contentHash,
    this.coverImagePath,
    this.updateTime,
  });

  factory SyncBookData.fromMap(Map<String, dynamic> map) {
    return SyncBookData(
      id: map['id'] as int?,
      title: map['title'] as String,
      author: map['author'] as String? ?? '未知',
      filePath: map['filePath'] as String,
      format: map['format'] as String,
      currentPage: map['currentPage'] as int? ?? 0,
      totalPages: map['totalPages'] as int? ?? 1,
      importDate: map['importDate'] as int,
      contentHash: map['content_hash'] as String?,
      coverImagePath: map['cover_image_path'] as String?,
      updateTime: map['update_time'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'format': format,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'importDate': importDate,
      'content_hash': contentHash,
      'cover_image_path': coverImagePath,
      'update_time': updateTime,
    };
  }

  /// 生成去重键
  String get uniqueKey => 'book:${contentHash ?? filePath}';
}

/// 书签同步数据
class SyncBookmarkData {
  final int? id;
  final int bookId;
  final int pageNumber;
  final String note;
  final int createDate;
  final String? cfi;

  SyncBookmarkData({
    this.id,
    required this.bookId,
    required this.pageNumber,
    required this.note,
    required this.createDate,
    this.cfi,
  });

  factory SyncBookmarkData.fromMap(Map<String, dynamic> map) {
    return SyncBookmarkData(
      id: map['id'] as int?,
      bookId: map['bookId'] as int,
      pageNumber: map['pageNumber'] as int,
      note: map['note'] as String? ?? '',
      createDate: map['createDate'] as int,
      cfi: map['cfi'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bookId': bookId,
      'pageNumber': pageNumber,
      'note': note,
      'createDate': createDate,
      'cfi': cfi,
    };
  }

  /// 生成去重键
  String get uniqueKey => 'bookmark:$bookId:$pageNumber';
}

/// 笔记/高亮同步数据
class SyncNoteData {
  final int? id;
  final int bookId;
  final String content;
  final String cfi;
  final String chapter;
  final String type;
  final String color;
  final String? readerNote;
  final int? pageNumber;
  final int? startOffset;
  final int? endOffset;
  final String? createTime;
  final String updateTime;

  SyncNoteData({
    this.id,
    required this.bookId,
    required this.content,
    required this.cfi,
    required this.chapter,
    required this.type,
    required this.color,
    this.readerNote,
    this.pageNumber,
    this.startOffset,
    this.endOffset,
    this.createTime,
    required this.updateTime,
  });

  factory SyncNoteData.fromMap(Map<String, dynamic> map) {
    return SyncNoteData(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      content: map['content'] as String,
      cfi: map['cfi'] as String,
      chapter: map['chapter'] as String,
      type: map['type'] as String,
      color: map['color'] as String,
      readerNote: map['reader_note'] as String?,
      pageNumber: map['page_number'] as int?,
      startOffset: map['start_offset'] as int?,
      endOffset: map['end_offset'] as int?,
      createTime: map['create_time'] as String?,
      updateTime: map['update_time'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'book_id': bookId,
      'content': content,
      'cfi': cfi,
      'chapter': chapter,
      'type': type,
      'color': color,
      'reader_note': readerNote,
      'page_number': pageNumber,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'create_time': createTime,
      'update_time': updateTime,
    };
  }

  /// 生成去重键
  String get uniqueKey => 'note:$bookId:$cfi:$startOffset:$endOffset';
}

/// 阅读进度同步数据
class SyncProgressData {
  final int bookId;
  final String filePath;
  final int currentPage;
  final int totalPages;
  final String? updateTime;

  SyncProgressData({
    required this.bookId,
    required this.filePath,
    required this.currentPage,
    required this.totalPages,
    this.updateTime,
  });

  factory SyncProgressData.fromMap(Map<String, dynamic> map) {
    return SyncProgressData(
      bookId: map['bookId'] as int,
      filePath: map['filePath'] as String,
      currentPage: map['currentPage'] as int,
      totalPages: map['totalPages'] as int? ?? 1,
      updateTime: map['update_time'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'filePath': filePath,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'update_time': updateTime,
    };
  }

  /// 生成去重键
  String get uniqueKey => 'progress:$bookId';
}

/// 阅读统计同步数据
class SyncStatsData {
  final String date;
  final int durationInSeconds;

  SyncStatsData({
    required this.date,
    required this.durationInSeconds,
  });

  factory SyncStatsData.fromMap(Map<String, dynamic> map) {
    return SyncStatsData(
      date: map['date'] as String,
      durationInSeconds: map['durationInSeconds'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'durationInSeconds': durationInSeconds,
    };
  }

  /// 生成去重键
  String get uniqueKey => 'stats:$date';
}

/// 书源同步数据
class SyncSourceData {
  final String id;
  final String bookSourceName;
  final String bookSourceGroup;
  final String bookSourceComment;
  final int bookSourceType;
  final String bookSourceUrl;
  final int bookSourceVersion;
  final bool enabled;
  final bool enabledExplore;
  final int lastUpdateTime;
  final int weight;
  final Map<String, dynamic>? ruleSearch;
  final Map<String, dynamic>? ruleExplore;
  final Map<String, dynamic>? ruleBookInfo;
  final Map<String, dynamic>? ruleToc;
  final Map<String, dynamic>? ruleContent;
  final Map<String, dynamic>? variableMap;
  final Map<String, dynamic>? httpConfig;
  final Map<String, dynamic>? header;
  final String? loginUrl;
  final String? loginUi;
  final int respondTime;

  SyncSourceData({
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
    this.variableMap,
    this.httpConfig,
    this.header,
    this.loginUrl,
    this.loginUi,
    required this.respondTime,
  });

  factory SyncSourceData.fromMap(Map<String, dynamic> map) {
    return SyncSourceData(
      id: map['id'] as String,
      bookSourceName: map['book_source_name'] as String,
      bookSourceGroup: map['book_source_group'] as String? ?? '',
      bookSourceComment: map['book_source_comment'] as String? ?? '',
      bookSourceType: map['book_source_type'] as int? ?? 0,
      bookSourceUrl: map['book_source_url'] as String,
      bookSourceVersion: map['book_source_version'] as int? ?? 1,
      enabled: (map['enabled'] as int? ?? 1) == 1,
      enabledExplore: (map['enabled_explore'] as int? ?? 1) == 1,
      lastUpdateTime: map['last_update_time'] as int? ?? 0,
      weight: map['weight'] as int? ?? 0,
      ruleSearch: map['rule_search'] as Map<String, dynamic>?,
      ruleExplore: map['rule_explore'] as Map<String, dynamic>?,
      ruleBookInfo: map['rule_book_info'] as Map<String, dynamic>?,
      ruleToc: map['rule_toc'] as Map<String, dynamic>?,
      ruleContent: map['rule_content'] as Map<String, dynamic>?,
      variableMap: map['variable_map'] as Map<String, dynamic>?,
      httpConfig: map['http_config'] as Map<String, dynamic>?,
      header: map['header'] as Map<String, dynamic>?,
      loginUrl: map['login_url'] as String?,
      loginUi: map['login_ui'] as String?,
      respondTime: map['respond_time'] as int? ?? 180000,
    );
  }

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
      'rule_search': ruleSearch,
      'rule_explore': ruleExplore,
      'rule_book_info': ruleBookInfo,
      'rule_toc': ruleToc,
      'rule_content': ruleContent,
      'variable_map': variableMap,
      'http_config': httpConfig,
      'header': header,
      'login_url': loginUrl,
      'login_ui': loginUi,
      'respond_time': respondTime,
    };
  }

  /// 生成去重键（使用 URL）
  String get uniqueKey => 'source:${bookSourceUrl}';
}

/// 设备元数据
class SyncDeviceMeta {
  final String deviceId;
  final String deviceName;
  final String? platform;
  final DateTime firstSyncTime;
  final DateTime? lastSyncTime;

  SyncDeviceMeta({
    required this.deviceId,
    required this.deviceName,
    this.platform,
    required this.firstSyncTime,
    this.lastSyncTime,
  });

  factory SyncDeviceMeta.fromMap(Map<String, dynamic> map) {
    return SyncDeviceMeta(
      deviceId: map['device_id'] as String,
      deviceName: map['device_name'] as String,
      platform: map['platform'] as String?,
      firstSyncTime: DateTime.parse(map['first_sync_time'] as String),
      lastSyncTime: map['last_sync_time'] != null
          ? DateTime.parse(map['last_sync_time'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'platform': platform,
      'first_sync_time': firstSyncTime.toIso8601String(),
      'last_sync_time': lastSyncTime?.toIso8601String(),
    };
  }
}
