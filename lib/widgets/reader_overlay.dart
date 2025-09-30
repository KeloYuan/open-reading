import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:battery_plus/battery_plus.dart';
import '../providers/reader_providers.dart';

/// 阅读页面信息浮层
///
/// 显示顶部状态信息（时间、电量）和底部进度信息（页码、进度）
/// 浮于文本内容之上，提供必要的阅读信息
class ReaderOverlay extends StatefulWidget {
  /// 是否显示状态栏
  final bool showStatusBar;

  /// 是否显示进度
  final bool showProgress;

  const ReaderOverlay({
    Key? key,
    this.showStatusBar = true,
    this.showProgress = true,
  }) : super(key: key);

  @override
  State<ReaderOverlay> createState() => _ReaderOverlayState();
}

class _ReaderOverlayState extends State<ReaderOverlay> {
  Timer? _timeUpdateTimer;
  String _currentTime = '';
  int _batteryLevel = 100;

  final Battery _battery = Battery();

  @override
  void initState() {
    super.initState();
    _initializeOverlay();
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
    super.dispose();
  }

  /// 初始化浮层
  void _initializeOverlay() {
    _updateTime();
    _updateBatteryLevel();

    // 每分钟更新一次时间
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateTime();
      _updateBatteryLevel();
    });
  }

  /// 更新时间
  void _updateTime() {
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (mounted && timeString != _currentTime) {
      setState(() {
        _currentTime = timeString;
      });
    }
  }

  /// 更新电池电量
  Future<void> _updateBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted && level != _batteryLevel) {
        setState(() {
          _batteryLevel = level;
        });
      }
    } catch (e) {
      debugPrint('获取电池电量失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReaderSettingsNotifier>(
      builder: (context, settingsNotifier, child) {
        final settings = settingsNotifier.state;

        return Stack(
          children: [
            // 顶部状态栏
            if (widget.showStatusBar) _buildTopStatusBar(settings),

            // 底部进度栏
            if (widget.showProgress) _buildBottomProgressBar(settings),
          ],
        );
      },
    );
  }

  /// 构建顶部状态栏
  Widget _buildTopStatusBar(ReaderSettings settings) {
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 左侧：时间
            _buildTimeDisplay(settings),

            // 右侧：电池电量
            _buildBatteryDisplay(settings),
          ],
        ),
      ),
    );
  }

  /// 构建时间显示
  Widget _buildTimeDisplay(ReaderSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: settings.textStyle.color?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _currentTime,
        style: settings.textStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: settings.textStyle.color?.withOpacity(0.8),
        ),
      ),
    );
  }

  /// 构建电池显示
  Widget _buildBatteryDisplay(ReaderSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: settings.textStyle.color?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getBatteryIcon(),
            size: 16,
            color: _getBatteryColor(settings),
          ),
          const SizedBox(width: 4),
          Text(
            '$_batteryLevel%',
            style: settings.textStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: settings.textStyle.color?.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取电池图标
  IconData _getBatteryIcon() {
    if (_batteryLevel >= 90) return Icons.battery_full;
    if (_batteryLevel >= 60) return Icons.battery_5_bar;
    if (_batteryLevel >= 40) return Icons.battery_3_bar;
    if (_batteryLevel >= 20) return Icons.battery_2_bar;
    if (_batteryLevel >= 10) return Icons.battery_1_bar;
    return Icons.battery_0_bar;
  }

  /// 获取电池颜色
  Color _getBatteryColor(ReaderSettings settings) {
    final baseColor = settings.textStyle.color ?? Colors.black;

    if (_batteryLevel <= 20) {
      return Colors.red;
    } else if (_batteryLevel <= 40) {
      return Colors.orange;
    } else {
      return baseColor.withOpacity(0.8);
    }
  }

  /// 构建底部进度栏
  Widget _buildBottomProgressBar(ReaderSettings settings) {
    return Consumer<ReaderPaginationNotifier>(
      builder: (context, paginationNotifier, child) {
        final paginationState = paginationNotifier.state;
        final pageInfo = paginationState.pages.isEmpty
            ? '0/0'
            : '${paginationState.currentPageIndex + 1}/${paginationState.totalPages}';
        final progress = paginationState.progress;

        return Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左侧：页码信息
                _buildPageInfo(pageInfo, settings),

                // 右侧：阅读进度百分比
                _buildProgressInfo(progress, settings),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建页码信息
  Widget _buildPageInfo(String pageInfo, ReaderSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: settings.textStyle.color?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        pageInfo,
        style: settings.textStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: settings.textStyle.color?.withOpacity(0.7),
        ),
      ),
    );
  }

  /// 构建进度信息
  Widget _buildProgressInfo(double progress, ReaderSettings settings) {
    final progressPercent = (progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: settings.textStyle.color?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1.5),
              color: settings.textStyle.color?.withOpacity(0.2),
            ),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                settings.textStyle.color?.withOpacity(0.6) ?? Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 百分比文字
          Text(
            '$progressPercent%',
            style: settings.textStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: settings.textStyle.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
