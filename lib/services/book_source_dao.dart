import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/book_source.dart';
import 'database_service.dart';

/// 书源数据访问对象
/// 处理书源的CRUD操作和数据库管理
class BookSourceDao {
  static const String tableName = 'book_sources';

  /// 获取数据库实例
  static Future<Database> get _db async {
    return await DatabaseService().database;
  }

  /// 创建书源表（已移至DatabaseService）
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        book_source_name TEXT NOT NULL,
        book_source_group TEXT NOT NULL DEFAULT '',
        book_source_comment TEXT NOT NULL DEFAULT '',
        book_source_type INTEGER NOT NULL DEFAULT 0,
        book_source_url TEXT NOT NULL,
        book_source_version INTEGER NOT NULL DEFAULT 1,
        enabled INTEGER NOT NULL DEFAULT 1,
        enabled_explore INTEGER NOT NULL DEFAULT 1,
        last_update_time INTEGER NOT NULL,
        weight INTEGER NOT NULL DEFAULT 0,
        rule_search TEXT,
        rule_explore TEXT,
        rule_book_info TEXT,
        rule_toc TEXT,
        rule_content TEXT,
        variable_map TEXT,
        http_config TEXT,
        header TEXT,
        login_url TEXT,
        login_ui TEXT,
        respond_time INTEGER NOT NULL DEFAULT 180000,
        created_time INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
        updated_time INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
      )
    ''');

    // 创建索引
    await db.execute(
      'CREATE INDEX idx_book_source_name ON $tableName (book_source_name)',
    );
    await db.execute(
      'CREATE INDEX idx_book_source_group ON $tableName (book_source_group)',
    );
    await db.execute(
      'CREATE INDEX idx_book_source_enabled ON $tableName (enabled)',
    );
    await db.execute(
      'CREATE INDEX idx_book_source_type ON $tableName (book_source_type)',
    );
  }

  /// 插入书源
  static Future<int> insert(BookSource bookSource) async {
    final db = await _db;
    final map = _bookSourceToDbMap(bookSource);

    try {
      await db.insert(
        tableName,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return 1;
    } catch (e) {
      print('插入书源失败: $e');
      return 0;
    }
  }

  /// 批量插入书源
  static Future<int> insertBatch(List<BookSource> bookSources) async {
    if (bookSources.isEmpty) return 0;

    final db = await _db;
    final batch = db.batch();

    for (final bookSource in bookSources) {
      final map = _bookSourceToDbMap(bookSource);
      batch.insert(
        tableName,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    try {
      final results = await batch.commit();
      return results.length;
    } catch (e) {
      print('批量插入书源失败: $e');
      return 0;
    }
  }

  /// 更新书源
  static Future<int> update(BookSource bookSource) async {
    final db = await _db;
    final map = _bookSourceToDbMap(bookSource);
    map['updated_time'] = DateTime.now().millisecondsSinceEpoch;

    try {
      return await db.update(
        tableName,
        map,
        where: 'id = ?',
        whereArgs: [bookSource.id],
      );
    } catch (e) {
      print('更新书源失败: $e');
      return 0;
    }
  }

  /// 删除书源
  static Future<int> delete(String id) async {
    final db = await _db;

    try {
      return await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('删除书源失败: $e');
      return 0;
    }
  }

  /// 批量删除书源
  static Future<int> deleteBatch(List<String> ids) async {
    if (ids.isEmpty) return 0;

    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');

    try {
      return await db.delete(
        tableName,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    } catch (e) {
      print('批量删除书源失败: $e');
      return 0;
    }
  }

  /// 根据ID获取书源
  static Future<BookSource?> getById(String id) async {
    final db = await _db;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return _dbMapToBookSource(maps.first);
      }
      return null;
    } catch (e) {
      print('获取书源失败: $e');
      return null;
    }
  }

  /// 获取所有书源
  static Future<List<BookSource>> getAll() async {
    final db = await _db;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        orderBy: 'weight DESC, book_source_name ASC',
      );

      return maps.map((map) => _dbMapToBookSource(map)).toList();
    } catch (e) {
      print('获取所有书源失败: $e');
      return [];
    }
  }

  /// 获取启用的书源
  static Future<List<BookSource>> getEnabled() async {
    final db = await _db;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        where: 'enabled = 1',
        orderBy: 'weight DESC, book_source_name ASC',
      );

      return maps.map((map) => _dbMapToBookSource(map)).toList();
    } catch (e) {
      print('获取启用书源失败: $e');
      return [];
    }
  }

  /// 按分组获取书源
  static Future<List<BookSource>> getByGroup(String group) async {
    final db = await _db;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        where: 'book_source_group = ?',
        whereArgs: [group],
        orderBy: 'weight DESC, book_source_name ASC',
      );

      return maps.map((map) => _dbMapToBookSource(map)).toList();
    } catch (e) {
      print('按分组获取书源失败: $e');
      return [];
    }
  }

  /// 按类型获取书源
  static Future<List<BookSource>> getByType(int type) async {
    final db = await _db;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        where: 'book_source_type = ? AND enabled = 1',
        whereArgs: [type],
        orderBy: 'weight DESC, book_source_name ASC',
      );

      return maps.map((map) => _dbMapToBookSource(map)).toList();
    } catch (e) {
      print('按类型获取书源失败: $e');
      return [];
    }
  }

  /// 搜索书源
  static Future<List<BookSource>> search(String query) async {
    final db = await _db;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        where: '''
          book_source_name LIKE ? OR 
          book_source_group LIKE ? OR 
          book_source_comment LIKE ?
        ''',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'weight DESC, book_source_name ASC',
      );

      return maps.map((map) => _dbMapToBookSource(map)).toList();
    } catch (e) {
      print('搜索书源失败: $e');
      return [];
    }
  }

  /// 获取所有分组
  static Future<List<String>> getAllGroups() async {
    final db = await _db;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        columns: ['book_source_group'],
        distinct: true,
        where: 'book_source_group != ""',
        orderBy: 'book_source_group ASC',
      );

      return maps.map((map) => map['book_source_group'] as String).toList();
    } catch (e) {
      print('获取书源分组失败: $e');
      return [];
    }
  }

  /// 统计书源数量
  static Future<Map<String, int>> getStats() async {
    final db = await _db;

    try {
      // 总数统计
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName',
      );
      final total = totalResult.first['count'] as int;

      // 启用数统计
      final enabledResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE enabled = 1',
      );
      final enabled = enabledResult.first['count'] as int;

      // 类型统计
      final typeResult = await db.rawQuery(
        'SELECT book_source_type, COUNT(*) as count FROM $tableName GROUP BY book_source_type',
      );
      final typeStats = <int, int>{};
      for (final row in typeResult) {
        typeStats[row['book_source_type'] as int] = row['count'] as int;
      }

      return {
        'total': total,
        'enabled': enabled,
        'disabled': total - enabled,
        'novel': typeStats[0] ?? 0,
        'comic': typeStats[1] ?? 0,
        'audio': typeStats[2] ?? 0,
      };
    } catch (e) {
      print('获取书源统计失败: $e');
      return {};
    }
  }

  /// 更新书源启用状态
  static Future<int> updateEnabled(String id, bool enabled) async {
    final db = await _db;

    try {
      return await db.update(
        tableName,
        {
          'enabled': enabled ? 1 : 0,
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('更新书源启用状态失败: $e');
      return 0;
    }
  }

  /// 更新书源发现启用状态
  static Future<int> updateEnabledExplore(String id, bool enabled) async {
    final db = await _db;

    try {
      return await db.update(
        tableName,
        {
          'enabled_explore': enabled ? 1 : 0,
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('更新书源发现启用状态失败: $e');
      return 0;
    }
  }

  /// 更新书源权重
  static Future<int> updateWeight(String id, int weight) async {
    final db = await _db;

    try {
      return await db.update(
        tableName,
        {
          'weight': weight,
          'updated_time': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('更新书源权重失败: $e');
      return 0;
    }
  }

  /// 清空所有书源
  static Future<int> deleteAll() async {
    final db = await _db;

    try {
      return await db.delete(tableName);
    } catch (e) {
      print('清空书源失败: $e');
      return 0;
    }
  }

  /// 从JSON文件导入书源
  static Future<int> importFromJson(String jsonString) async {
    try {
      final jsonData = jsonDecode(jsonString);
      final List<BookSource> bookSources = [];

      if (jsonData is List) {
        // JSON数组格式
        for (final item in jsonData) {
          if (item is Map<String, dynamic>) {
            try {
              final bookSource = BookSource.fromJson(item);
              bookSources.add(bookSource);
            } catch (e) {
              print('解析书源失败: $e');
            }
          }
        }
      } else if (jsonData is Map<String, dynamic>) {
        // 单个书源格式
        try {
          final bookSource = BookSource.fromJson(jsonData);
          bookSources.add(bookSource);
        } catch (e) {
          print('解析书源失败: $e');
        }
      }

      return await insertBatch(bookSources);
    } catch (e) {
      print('导入书源失败: $e');
      return 0;
    }
  }

  /// 导出书源为JSON
  static Future<String> exportToJson([List<String>? ids]) async {
    try {
      List<BookSource> bookSources;

      if (ids != null && ids.isNotEmpty) {
        // 导出指定书源
        bookSources = [];
        for (final id in ids) {
          final bookSource = await getById(id);
          if (bookSource != null) {
            bookSources.add(bookSource);
          }
        }
      } else {
        // 导出所有书源
        bookSources = await getAll();
      }

      final jsonList = bookSources.map((source) => source.toJson()).toList();
      return jsonEncode(jsonList);
    } catch (e) {
      print('导出书源失败: $e');
      return '[]';
    }
  }

  /// 将BookSource转换为数据库Map
  static Map<String, dynamic> _bookSourceToDbMap(BookSource bookSource) {
    return {
      'id': bookSource.id,
      'book_source_name': bookSource.bookSourceName,
      'book_source_group': bookSource.bookSourceGroup,
      'book_source_comment': bookSource.bookSourceComment,
      'book_source_type': bookSource.bookSourceType,
      'book_source_url': bookSource.bookSourceUrl,
      'book_source_version': bookSource.bookSourceVersion,
      'enabled': bookSource.enabled ? 1 : 0,
      'enabled_explore': bookSource.enabledExplore ? 1 : 0,
      'last_update_time': bookSource.lastUpdateTime,
      'weight': bookSource.weight,
      'rule_search': bookSource.ruleSearch != null
          ? jsonEncode(bookSource.ruleSearch!.toJson())
          : null,
      'rule_explore': bookSource.ruleExplore != null
          ? jsonEncode(bookSource.ruleExplore!.toJson())
          : null,
      'rule_book_info': bookSource.ruleBookInfo != null
          ? jsonEncode(bookSource.ruleBookInfo!.toJson())
          : null,
      'rule_toc': bookSource.ruleToc != null
          ? jsonEncode(bookSource.ruleToc!.toJson())
          : null,
      'rule_content': bookSource.ruleContent != null
          ? jsonEncode(bookSource.ruleContent!.toJson())
          : null,
      'variable_map': jsonEncode(bookSource.variableMap),
      'http_config': jsonEncode(bookSource.httpConfig),
      'header': jsonEncode(bookSource.header),
      'login_url': bookSource.loginUrl,
      'login_ui': bookSource.loginUi,
      'respond_time': bookSource.respondTime,
    };
  }

  /// 将数据库Map转换为BookSource
  static BookSource _dbMapToBookSource(Map<String, dynamic> map) {
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
          ? RuleSearch.fromJson(jsonDecode(map['rule_search']))
          : null,
      ruleExplore: map['rule_explore'] != null
          ? RuleExplore.fromJson(jsonDecode(map['rule_explore']))
          : null,
      ruleBookInfo: map['rule_book_info'] != null
          ? RuleBookInfo.fromJson(jsonDecode(map['rule_book_info']))
          : null,
      ruleToc: map['rule_toc'] != null
          ? RuleToc.fromJson(jsonDecode(map['rule_toc']))
          : null,
      ruleContent: map['rule_content'] != null
          ? RuleContent.fromJson(jsonDecode(map['rule_content']))
          : null,
      variableMap: Map<String, String>.from(
        jsonDecode(map['variable_map'] ?? '{}'),
      ),
      httpConfig: Map<String, String>.from(
        jsonDecode(map['http_config'] ?? '{}'),
      ),
      header: Map<String, String>.from(jsonDecode(map['header'] ?? '{}')),
      loginUrl: map['login_url'],
      loginUi: map['login_ui'],
      respondTime: map['respond_time'] ?? 180000,
    );
  }
}
