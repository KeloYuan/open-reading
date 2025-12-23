import 'dart:async';
import 'dart:collection';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

// 类型别名
typedef OnDatabaseCreateFn = Future<void> Function(Database db, int version);
typedef OnDatabaseUpgradeFn = Future<void> Function(
    Database db, int oldVersion, int newVersion);

/// 数据库连接池
///
/// 管理多个数据库连接，提高并发性能
/// 支持连接复用、自动回收、连接健康检查
class DatabaseConnectionPool {
  // 单例模式
  static final DatabaseConnectionPool _instance =
      DatabaseConnectionPool._internal();
  factory DatabaseConnectionPool() => _instance;
  DatabaseConnectionPool._internal();

  // 连接池配置
  static const int _maxConnections = 5;
  static const int _minConnections = 2;
  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const Duration _healthCheckInterval = Duration(minutes: 5);

  // 连接池状态
  final Queue<DatabaseConnection> _availableConnections = Queue();
  final Set<DatabaseConnection> _allConnections = {};
  final Queue<Completer<DatabaseConnection>> _waitingQueue = Queue();

  Timer? _healthCheckTimer;
  bool _isInitialized = false;
  String? _databasePath;

  /// 初始化连接池
  ///
  /// [databasePath] 数据库文件路径
  /// [onCreate] 数据库创建回调
  /// [onUpgrade] 数据库升级回调
  /// [version] 数据库版本
  Future<void> initialize({
    required String databasePath,
    OnDatabaseCreateFn? onCreate,
    OnDatabaseUpgradeFn? onUpgrade,
    int version = 1,
  }) async {
    if (_isInitialized) {
      debugPrint('数据库连接池已初始化');
      return;
    }

    _databasePath = databasePath;

    // 创建最小连接数
    for (int i = 0; i < _minConnections; i++) {
      final connection = await _createConnection(
        databasePath,
        onCreate,
        onUpgrade,
        version,
      );
      _addConnection(connection);
    }

    // 启动健康检查
    _startHealthCheck();

    _isInitialized = true;
    debugPrint('数据库连接池初始化完成，初始连接数: $_minConnections');
  }

  /// 获取数据库连接
  ///
  /// 返回可用的数据库连接
  Future<DatabaseConnection> getConnection() async {
    if (!_isInitialized) {
      throw StateError('连接池未初始化，请先调用initialize()');
    }

    // 1. 检查是否有可用连接
    if (_availableConnections.isNotEmpty) {
      final connection = _availableConnections.removeFirst();
      if (await _isConnectionHealthy(connection)) {
        connection.inUse = true;
        return connection;
      } else {
        // 连接不健康，移除并创建新连接
        _removeConnection(connection);
        return await getConnection();
      }
    }

    // 2. 检查是否可以创建新连接
    if (_allConnections.length < _maxConnections) {
      final connection = await _createNewConnection();
      connection.inUse = true;
      return connection;
    }

    // 3. 等待连接释放
    final completer = Completer<DatabaseConnection>();
    _waitingQueue.add(completer);

    // 设置超时
    Timer(_connectionTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('获取数据库连接超时', _connectionTimeout),
        );
      }
    });

    return completer.future;
  }

  /// 释放连接
  ///
  /// [connection] 要释放的连接
  Future<void> releaseConnection(DatabaseConnection connection) async {
    if (!_allConnections.contains(connection)) {
      debugPrint('警告：尝试释放不存在的连接');
      return;
    }

    connection.inUse = false;
    connection.lastUsed = DateTime.now();

    // 检查是否有等待的请求
    if (_waitingQueue.isNotEmpty) {
      final completer = _waitingQueue.removeFirst();
      connection.inUse = true;
      completer.complete(connection);
    } else {
      _availableConnections.add(connection);
    }
  }

  /// 执行数据库操作
  ///
  /// [operation] 要执行的操作
  /// [transaction] 是否在事务中执行
  Future<T> execute<T>(
    Future<T> Function(DatabaseConnection) operation, {
    bool transaction = false,
  }) async {
    final connection = await getConnection();

    try {
      if (transaction) {
        return await connection.transaction((txn) => operation(connection));
      } else {
        return await operation(connection);
      }
    } finally {
      await releaseConnection(connection);
    }
  }

  /// 创建新连接
  Future<DatabaseConnection> _createNewConnection() async {
    if (_databasePath == null) {
      throw StateError('数据库路径未设置');
    }

    return await _createConnection(_databasePath!);
  }

  /// 创建数据库连接
  Future<DatabaseConnection> _createConnection(
    String databasePath, [
    OnDatabaseCreateFn? onCreate,
    OnDatabaseUpgradeFn? onUpgrade,
    int version = 1,
  ]) async {
    try {
      final database = await openDatabase(
        databasePath,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        // 连接池配置
        singleInstance: false,
        readOnly: false,
      );

      final connection = DatabaseConnection(
        database: database,
        created: DateTime.now(),
        lastUsed: DateTime.now(),
      );

      debugPrint('创建新的数据库连接: ${connection.id}');
      return connection;
    } catch (e) {
      debugPrint('创建数据库连接失败: $e');
      rethrow;
    }
  }

  /// 添加连接到池
  void _addConnection(DatabaseConnection connection) {
    _allConnections.add(connection);
    _availableConnections.add(connection);
  }

  /// 移除连接
  Future<void> _removeConnection(DatabaseConnection connection) async {
    _allConnections.remove(connection);
    _availableConnections.remove(connection);

    try {
      await connection.database.close();
      debugPrint('关闭数据库连接: ${connection.id}');
    } catch (e) {
      debugPrint('关闭数据库连接失败: $e');
    }
  }

  /// 检查连接健康状态
  Future<bool> _isConnectionHealthy(DatabaseConnection connection) async {
    try {
      // 执行简单查询检查连接
      await connection.database.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      debugPrint('数据库连接不健康: ${connection.id}, 错误: $e');
      return false;
    }
  }

  /// 启动健康检查
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) {
      _performHealthCheck();
    });
  }

  /// 执行健康检查
  Future<void> _performHealthCheck() async {
    debugPrint('执行数据库连接健康检查...');

    final unhealthyConnections = <DatabaseConnection>[];

    for (final connection in _allConnections) {
      if (!connection.inUse) {
        final isHealthy = await _isConnectionHealthy(connection);
        if (!isHealthy) {
          unhealthyConnections.add(connection);
        }
      }
    }

    // 移除不健康的连接
    for (final connection in unhealthyConnections) {
      await _removeConnection(connection);
    }

    // 确保最小连接数
    final currentCount = _allConnections.length;
    if (currentCount < _minConnections) {
      for (int i = 0; i < _minConnections - currentCount; i++) {
        try {
          final connection = await _createNewConnection();
          _addConnection(connection);
        } catch (e) {
          debugPrint('健康检查中创建连接失败: $e');
        }
      }
    }

    debugPrint('健康检查完成，当前连接数: ${_allConnections.length}');
  }

  /// 获取连接池统计信息
  PoolStats getStats() {
    return PoolStats(
      totalConnections: _allConnections.length,
      availableConnections: _availableConnections.length,
      inUseConnections: _allConnections.length - _availableConnections.length,
      waitingRequests: _waitingQueue.length,
    );
  }

  /// 关闭连接池
  Future<void> close() async {
    _healthCheckTimer?.cancel();

    // 完成所有等待的请求（失败）
    while (_waitingQueue.isNotEmpty) {
      final completer = _waitingQueue.removeFirst();
      if (!completer.isCompleted) {
        completer.completeError(StateError('连接池已关闭'));
      }
    }

    // 关闭所有连接
    final connections = List<DatabaseConnection>.from(_allConnections);
    for (final connection in connections) {
      await _removeConnection(connection);
    }

    _isInitialized = false;
    debugPrint('数据库连接池已关闭');
  }
}

/// 数据库连接包装器
class DatabaseConnection {
  final Database database;
  final DateTime created;
  final String id;
  bool inUse = false;
  DateTime lastUsed;

  DatabaseConnection({
    required this.database,
    required this.created,
    required this.lastUsed,
  }) : id = _generateId();

  /// 生成连接ID
  static String _generateId() {
    return 'conn_${DateTime.now().millisecondsSinceEpoch}_${Object().hashCode}';
  }

  /// 执行事务
  Future<T> transaction<T>(Future<T> Function(Transaction) action) async {
    return await database.transaction(action);
  }

  /// 执行查询
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await database.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// 插入数据
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    return await database.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  /// 更新数据
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    return await database.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  /// 删除数据
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return await database.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// 执行原始SQL
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    return await database.rawQuery(sql, arguments);
  }

  /// 执行原始SQL（无返回值）
  Future<void> execute(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    return await database.execute(sql);
  }
}

/// 连接池统计信息
class PoolStats {
  final int totalConnections;
  final int availableConnections;
  final int inUseConnections;
  final int waitingRequests;

  PoolStats({
    required this.totalConnections,
    required this.availableConnections,
    required this.inUseConnections,
    required this.waitingRequests,
  });

  @override
  String toString() {
    return 'PoolStats('
        'total: $totalConnections, '
        'available: $availableConnections, '
        'inUse: $inUseConnections, '
        'waiting: $waitingRequests'
        ')';
  }
}

/// 数据库操作辅助类
///
/// 提供便捷的数据库操作方法
class DatabaseHelper {
  static final DatabaseConnectionPool _pool = DatabaseConnectionPool();

  /// 初始化数据库
  static Future<void> initialize({
    required String databasePath,
    OnDatabaseCreateFn? onCreate,
    OnDatabaseUpgradeFn? onUpgrade,
    int version = 1,
  }) async {
    await _pool.initialize(
      databasePath: databasePath,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      version: version,
    );
  }

  /// 批量插入
  static Future<List<int>> batchInsert<T>(
    String table,
    List<Map<String, Object?>> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    return await _pool.execute((connection) async {
      final batch = connection.database.batch();

      for (final value in values) {
        batch.insert(table, value, conflictAlgorithm: conflictAlgorithm);
      }

      final results = await batch.commit();
      return results.cast<int>();
    });
  }

  /// 分页查询
  static Future<List<Map<String, Object?>>> queryWithPagination(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int page = 0,
    int pageSize = 20,
  }) async {
    final offset = page * pageSize;

    return await _pool.execute((connection) async {
      return await connection.query(
        table,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: pageSize,
        offset: offset,
      );
    });
  }

  /// 获取连接池统计
  static PoolStats getPoolStats() {
    return _pool.getStats();
  }

  /// 关闭连接池
  static Future<void> close() async {
    await _pool.close();
  }
}
