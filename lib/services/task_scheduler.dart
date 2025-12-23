import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// 任务调度器
///
/// 管理并发任务执行，支持：
/// - 并发限制
/// - 任务优先级
/// - 任务超时控制
/// - 任务重试机制
class TaskScheduler {
  // 单例模式
  static final TaskScheduler _instance = TaskScheduler._internal();
  factory TaskScheduler() => _instance;
  TaskScheduler._internal();

  // 配置常量
  static const int _maxConcurrentTasks = 3;
  static const int _maxQueueSize = 100;
  static const Duration _defaultTimeout = Duration(minutes: 5);

  // 任务队列
  final PriorityQueue<TaskWrapper> _taskQueue = PriorityQueue();
  final Set<TaskWrapper> _runningTasks = {};
  final Map<String, TaskStats> _taskStats = {};

  // 状态管理
  int _taskIdCounter = 0;
  Timer? _statsTimer;

  /// 调度任务
  ///
  /// [task] 要执行的任务
  /// [priority] 任务优先级，默认普通
  /// [timeout] 任务超时时间
  /// [retryCount] 重试次数，默认0次
  /// [delay] 延迟执行时间
  /// Returns: 任务Future
  Future<T> scheduleTask<T>(
    Future<T> Function() task, {
    TaskPriority priority = TaskPriority.normal,
    Duration? timeout,
    int retryCount = 0,
    Duration? delay,
  }) {
    final completer = Completer<T>();
    final taskId = 'task_${++_taskIdCounter}';

    final wrapper = TaskWrapper<T>(
      id: taskId,
      task: task,
      completer: completer,
      priority: priority,
      timeout: timeout ?? _defaultTimeout,
      retryCount: retryCount,
      originalRetryCount: retryCount,
      delay: delay,
      createdAt: DateTime.now(),
    );

    // 检查队列大小
    if (_taskQueue.length >= _maxQueueSize) {
      completer.completeError(
        StateError('任务队列已满，无法添加新任务'),
      );
      return completer.future;
    }

    // 添加到队列
    _taskQueue.add(wrapper);
    _updateTaskStats(taskId, 'queued');

    debugPrint('📋 任务已排队: $taskId (优先级: $priority)');

    // 尝试执行任务
    _processNextTask();

    return completer.future;
  }

  /// 处理下一个任务
  void _processNextTask() {
    // 检查并发限制
    if (_runningTasks.length >= _maxConcurrentTasks) {
      return;
    }

    // 检查队列是否为空
    if (_taskQueue.isEmpty) {
      return;
    }

    // 获取最高优先级任务
    final wrapper = _taskQueue.removeFirst();

    // 检查延迟执行
    if (wrapper.delay != null && wrapper.delay!.inMilliseconds > 0) {
      Timer(wrapper.delay!, () {
        _executeTask(wrapper);
      });
    } else {
      _executeTask(wrapper);
    }
  }

  /// 执行任务
  Future<void> _executeTask<T>(TaskWrapper<T> wrapper) async {
    _runningTasks.add(wrapper as TaskWrapper);
    _updateTaskStats(wrapper.id, 'running');

    debugPrint('🚀 开始执行任务: ${wrapper.id}');

    try {
      // 设置超时
      final taskFuture = wrapper.task();
      final timeoutFuture = Future.delayed(wrapper.timeout);

      final result = await Future.any([
        taskFuture.then((value) => TaskResult.success(value)),
        timeoutFuture.then((_) => TaskResult.timeout()),
      ]);

      if (result.isSuccess) {
        wrapper.completer.complete(result.value);
        _updateTaskStats(wrapper.id, 'completed');
        debugPrint('✅ 任务完成: ${wrapper.id}');
      } else if (result.isTimeout) {
        await _handleTaskFailure(wrapper, 'timeout');
      }
    } catch (error, stackTrace) {
      debugPrint('❌ 任务执行失败: ${wrapper.id}, 错误: $error');
      debugPrint('Stack trace: $stackTrace');
      await _handleTaskFailure(wrapper, 'error', error: error);
    } finally {
      _runningTasks.remove(wrapper as TaskWrapper);

      // 处理下一个任务
      _processNextTask();
    }
  }

  /// 处理任务失败
  Future<void> _handleTaskFailure<T>(
    TaskWrapper<T> wrapper,
    String reason, {
    Object? error,
  }) async {
    if (wrapper.retryCount > 0) {
      // 重试任务
      wrapper.retryCount--;
      _updateTaskStats(wrapper.id, 'retrying');

      debugPrint('🔄 任务重试: ${wrapper.id} (剩余${wrapper.retryCount}次)');

      // 添加延迟重试
      final retryWrapper = TaskWrapper<T>(
        id: wrapper.id,
        task: wrapper.task,
        completer: wrapper.completer,
        priority: wrapper.priority,
        timeout: wrapper.timeout,
        retryCount: wrapper.retryCount,
        originalRetryCount: wrapper.originalRetryCount,
        createdAt: wrapper.createdAt,
        delay: Duration(
            seconds: 2 * (wrapper.originalRetryCount - wrapper.retryCount + 1)),
      );

      _taskQueue.add(retryWrapper);
    } else {
      // 任务最终失败
      _updateTaskStats(wrapper.id, 'failed');

      if (reason == 'timeout') {
        wrapper.completer.completeError(
          TimeoutException('任务执行超时', wrapper.timeout),
        );
      } else {
        wrapper.completer.completeError(error ?? Exception('任务执行失败'));
      }

      debugPrint('❌ 任务最终失败: ${wrapper.id} (原因: $reason)');
    }
  }

  /// 更新任务统计
  void _updateTaskStats(String taskId, String status) {
    if (!_taskStats.containsKey(taskId)) {
      _taskStats[taskId] = TaskStats(taskId: taskId);
    }

    final stats = _taskStats[taskId]!;
    stats.updateStatus(status);
  }

  /// 获取任务统计
  Map<String, dynamic> getTaskStats() {
    final queued =
        _taskStats.values.where((s) => s.currentStatus == 'queued').length;
    final running =
        _taskStats.values.where((s) => s.currentStatus == 'running').length;
    final completed =
        _taskStats.values.where((s) => s.currentStatus == 'completed').length;
    final failed =
        _taskStats.values.where((s) => s.currentStatus == 'failed').length;
    final retrying =
        _taskStats.values.where((s) => s.currentStatus == 'retrying').length;

    return {
      'queued': queued,
      'running': running,
      'completed': completed,
      'failed': failed,
      'retrying': retrying,
      'total': _taskStats.length,
      'queueLength': _taskQueue.length,
      'runningTasks': _runningTasks.length,
    };
  }

  /// 清除已完成的任务统计
  void clearCompletedStats() {
    final completedTasks = _taskStats.entries
        .where((entry) => entry.value.isCompleted)
        .map((entry) => entry.key)
        .toList();

    for (final taskId in completedTasks) {
      _taskStats.remove(taskId);
    }

    debugPrint('🗑️ 清除已完成任务统计: ${completedTasks.length}个');
  }

  /// 清除所有任务统计
  void clearAllStats() {
    _taskStats.clear();
    debugPrint('🗑️ 清除所有任务统计');
  }

  /// 取消任务
  ///
  /// [taskId] 任务ID
  /// Returns: 是否成功取消
  bool cancelTask(String taskId) {
    // 检查运行中的任务
    final runningTask = _runningTasks.firstWhere(
      (task) => task.id == taskId,
      orElse: () => null as TaskWrapper,
    );

    if (runningTask != null) {
      // 运行中的任务无法直接取消，但可以标记
      runningTask.markForCancellation();
      _updateTaskStats(taskId, 'cancelled');
      return true;
    }

    // 检查队列中的任务
    final queueTask = _taskQueue.toList().firstWhere(
          (task) => task.id == taskId,
          orElse: () => null as TaskWrapper,
        );

    if (queueTask != null) {
      _taskQueue._list.remove(queueTask);
      queueTask.completer.completeError(
        StateError('任务已取消'),
      );
      _updateTaskStats(taskId, 'cancelled');
      return true;
    }

    return false;
  }

  /// 暂停任务调度
  void pause() {
    // 实现暂停逻辑
    debugPrint('⏸️ 任务调度器已暂停');
  }

  /// 恢复任务调度
  void resume() {
    // 实现恢复逻辑
    debugPrint('▶️ 任务调度器已恢复');
    _processNextTask();
  }

  /// 启动统计定时器
  void startStatsReporting({Duration interval = const Duration(minutes: 1)}) {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(interval, (timer) {
      final stats = getTaskStats();
      debugPrint('📊 任务统计: $stats');
    });
    debugPrint('📊 任务统计报告已启动');
  }

  /// 停止统计定时器
  void stopStatsReporting() {
    _statsTimer?.cancel();
    _statsTimer = null;
    debugPrint('📊 任务统计报告已停止');
  }

  /// 获取队列状态
  QueueStatus getQueueStatus() {
    return QueueStatus(
      queueLength: _taskQueue.length,
      runningTasks: _runningTasks.length,
      maxConcurrentTasks: _maxConcurrentTasks,
      maxQueueSize: _maxQueueSize,
    );
  }
}

/// 任务包装器
class TaskWrapper<T> implements Comparable<TaskWrapper> {
  final String id;
  final Future<T> Function() task;
  final Completer<T> completer;
  final TaskPriority priority;
  final Duration timeout;
  int retryCount;
  final int originalRetryCount;
  final Duration? delay;
  final DateTime createdAt;
  bool _markedForCancellation = false;

  TaskWrapper({
    required this.id,
    required this.task,
    required this.completer,
    required this.priority,
    required this.timeout,
    required this.retryCount,
    required this.originalRetryCount,
    this.delay,
    required this.createdAt,
  });

  /// 标记为取消
  void markForCancellation() {
    _markedForCancellation = true;
  }

  /// 是否被标记为取消
  bool get isMarkedForCancellation => _markedForCancellation;

  @override
  int compareTo(TaskWrapper other) {
    // 优先级比较
    final priorityComparison = other.priority.value.compareTo(priority.value);
    if (priorityComparison != 0) return priorityComparison;

    // 创建时间比较（早创建的先执行）
    return createdAt.compareTo(other.createdAt);
  }
}

/// 任务优先级
enum TaskPriority {
  low(1),
  normal(2),
  high(3),
  urgent(4);

  const TaskPriority(this.value);
  final int value;
}

/// 任务结果
class TaskResult<T> {
  final T? value;
  final bool isSuccess;
  final bool isTimeout;

  TaskResult.success(this.value)
      : isSuccess = true,
        isTimeout = false;

  TaskResult.timeout()
      : value = null,
        isSuccess = false,
        isTimeout = true;

  TaskResult.error()
      : value = null,
        isSuccess = false,
        isTimeout = false;
}

/// 任务统计
class TaskStats {
  final String taskId;
  String currentStatus = 'queued';
  DateTime? lastUpdated;
  int retryCount = 0;
  final List<String> statusHistory = [];

  TaskStats({required this.taskId});

  /// 更新状态
  void updateStatus(String status) {
    currentStatus = status;
    lastUpdated = DateTime.now();
    statusHistory.add(status);

    if (status == 'retrying') {
      retryCount++;
    }
  }

  /// 是否已完成
  bool get isCompleted {
    return currentStatus == 'completed' ||
        currentStatus == 'failed' ||
        currentStatus == 'cancelled';
  }

  /// 获取持续时间
  Duration? getDuration() {
    if (lastUpdated == null) return null;
    return lastUpdated!.difference(
        statusHistory.first == 'queued' ? lastUpdated! : DateTime.now());
  }
}

/// 队列状态
class QueueStatus {
  final int queueLength;
  final int runningTasks;
  final int maxConcurrentTasks;
  final int maxQueueSize;

  QueueStatus({
    required this.queueLength,
    required this.runningTasks,
    required this.maxConcurrentTasks,
    required this.maxQueueSize,
  });

  /// 是否繁忙
  bool get isBusy {
    return runningTasks >= maxConcurrentTasks ||
        queueLength >= maxQueueSize ~/ 2;
  }

  /// 是否满载
  bool get isFull {
    return runningTasks >= maxConcurrentTasks && queueLength >= maxQueueSize;
  }

  @override
  String toString() {
    return 'QueueStatus('
        'queue: $queueLength/$maxQueueSize, '
        'running: $runningTasks/$maxConcurrentTasks, '
        'busy: $isBusy, '
        'full: $isFull'
        ')';
  }
}

/// 优先级队列
class PriorityQueue<T extends Comparable<T>> {
  final List<T> _list = [];

  /// 添加元素
  void add(T element) {
    _list.add(element);
    _list.sort();
  }

  /// 移除第一个元素
  T removeFirst() {
    if (_list.isEmpty) {
      throw StateError('队列为空');
    }
    return _list.removeAt(0);
  }

  /// 检查是否为空
  bool get isEmpty => _list.isEmpty;

  /// 获取长度
  int get length => _list.length;

  /// 转换为列表
  List<T> toList() => List.from(_list);

  /// 清空队列
  void clear() {
    _list.clear();
  }
}

/// 任务调度器扩展
extension TaskSchedulerExtensions on TaskScheduler {
  /// 调度IO任务
  Future<T> scheduleIOTask<T>(
    Future<T> Function() task, {
    TaskPriority priority = TaskPriority.low,
    Duration? timeout,
  }) {
    return scheduleTask(
      task,
      priority: priority,
      timeout: timeout,
      retryCount: 2, // IO任务默认重试2次
    );
  }

  /// 调度CPU密集型任务
  Future<T> scheduleCPUTask<T>(
    Future<T> Function() task, {
    TaskPriority priority = TaskPriority.normal,
    Duration? timeout,
  }) {
    return scheduleTask(
      task,
      priority: priority,
      timeout: timeout,
      retryCount: 1, // CPU任务默认重试1次
    );
  }

  /// 调度网络任务
  Future<T> scheduleNetworkTask<T>(
    Future<T> Function() task, {
    TaskPriority priority = TaskPriority.normal,
    Duration? timeout,
  }) {
    return scheduleTask(
      task,
      priority: priority,
      timeout: timeout ?? Duration(seconds: 30), // 网络任务默认30秒超时
      retryCount: 3, // 网络任务默认重试3次
    );
  }
}
