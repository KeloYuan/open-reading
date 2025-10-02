import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../providers/reader_providers.dart';
import '../services/tts/base_tts.dart';

/// TTS设置面板
///
/// 提供完整的TTS控制功能，包括：
/// - 播放控制（播放、暂停、停止、上一句、下一句）
/// - 音量、音调、语速调节
/// - 定时停止功能
class TtsSettingsSheet extends ConsumerStatefulWidget {
  const TtsSettingsSheet({super.key});

  @override
  ConsumerState<TtsSettingsSheet> createState() => _TtsSettingsSheetState();
}

class _TtsSettingsSheetState extends ConsumerState<TtsSettingsSheet> {
  double _stopMinutes = 0;
  Timer? _stopTimer;
  String? _errorMessage;

  @override
  void dispose() {
    _stopTimer?.cancel();
    super.dispose();
  }

  /// 开始定时停止
  void _startStopTimer() {
    _stopTimer?.cancel();

    if (_stopMinutes > 0) {
      _stopTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_stopMinutes > 5 / 60) {
          setState(() {
            _stopMinutes -= 5 / 60;
          });
        } else {
          ref.read(readerTtsProvider.notifier).stop();
          setState(() {
            _stopMinutes = 0;
          });
          timer.cancel();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ttsState = ref.watch(readerTtsProvider);
    final ttsNotifier = ref.read(readerTtsProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.record_voice_over_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '语音朗读',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 错误提示
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: colorScheme.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.close, size: 18, color: colorScheme.error),
                      onPressed: () => setState(() => _errorMessage = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

            // 状态指示
            _buildStatusIndicator(ttsState, colorScheme, theme),

            const SizedBox(height: 8),

            // 播放控制按钮
            _buildControlButtons(ttsState, ttsNotifier, colorScheme, theme),

            const SizedBox(height: 16),

            // 定时停止
            _buildStopTimer(colorScheme, theme),

            const SizedBox(height: 8),

            // 音量控制
            _buildSlider(
              icon: Icons.volume_up_rounded,
              label: '音量',
              value: ttsState.volume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              onChanged: (value) => ttsNotifier.updateVolume(value),
              colorScheme: colorScheme,
              theme: theme,
            ),

            // 音调控制
            _buildSlider(
              icon: Icons.graphic_eq_rounded,
              label: '音调',
              value: ttsState.pitch,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (value) => ttsNotifier.updatePitch(value),
              colorScheme: colorScheme,
              theme: theme,
            ),

            // 语速控制
            _buildSlider(
              icon: Icons.speed_rounded,
              label: '语速',
              value: ttsState.rate,
              min: 0.1,
              max: 2.0,
              divisions: 19,
              onChanged: (value) => ttsNotifier.updateRate(value),
              colorScheme: colorScheme,
              theme: theme,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// 构建状态指示器
  Widget _buildStatusIndicator(
    ReaderTtsState ttsState,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final isPlaying = ttsState.ttsState == TtsStateEnum.playing;
    final isPaused = ttsState.ttsState == TtsStateEnum.paused;

    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (isPlaying) {
      statusText = '正在播放';
      statusIcon = Icons.play_circle_filled;
      statusColor = colorScheme.primary;
    } else if (isPaused) {
      statusText = '已暂停';
      statusIcon = Icons.pause_circle_filled;
      statusColor = Colors.orange;
    } else {
      statusText = '已停止';
      statusIcon = Icons.stop_circle;
      statusColor = colorScheme.onSurface.withValues(alpha: 0.5);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建播放控制按钮
  Widget _buildControlButtons(
    ReaderTtsState ttsState,
    ReaderTtsNotifier ttsNotifier,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final isPlaying = ttsState.ttsState == TtsStateEnum.playing;
    final isPaused = ttsState.ttsState == TtsStateEnum.paused;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 上一句
          _buildControlButton(
            icon: Icons.skip_previous_rounded,
            label: '上一句',
            onPressed: () async {
              try {
                HapticFeedback.lightImpact();
                await ttsNotifier.previous();
                if (mounted) {
                  setState(() => _errorMessage = null);
                }
              } catch (e) {
                if (mounted) {
                  HapticFeedback.heavyImpact();
                  setState(() => _errorMessage = '上一句失败: $e');
                }
              }
            },
            colorScheme: colorScheme,
            theme: theme,
          ),

          // 主播放/停止按钮（带动画）
          _buildMainPlayStopButton(
            isPlaying: isPlaying,
            isPaused: isPaused,
            onPressed: () async {
              try {
                HapticFeedback.mediumImpact();

                if (isPlaying || isPaused) {
                  // 如果正在播放或暂停，点击即停止
                  await ttsNotifier.stop();
                  if (mounted) {
                    HapticFeedback.lightImpact();
                    setState(() => _errorMessage = null);
                  }
                } else {
                  // 如果已停止，点击即播放 - 直接传入当前页面内容
                  debugPrint('═══════════════════════════════════════');
                  debugPrint('🎬 用户点击了播放按钮');
                  debugPrint('═══════════════════════════════════════');

                  final paginationState = ref.read(readerPaginationProvider);
                  debugPrint('分页状态:');
                  debugPrint('  - 总页数: ${paginationState.pages.length}');
                  debugPrint('  - 当前页: ${paginationState.currentPageIndex}');

                  final currentContent = paginationState.currentPageContent;
                  debugPrint(
                      '  - 当前页内容: ${currentContent != null ? "有内容" : "null"}');

                  if (currentContent == null) {
                    debugPrint('❌ 错误: 当前页面内容为 null');
                    if (mounted) {
                      HapticFeedback.heavyImpact();
                      setState(() => _errorMessage = '当前页面内容为空（null）');
                    }
                    return;
                  }

                  if (currentContent.trim().isEmpty) {
                    debugPrint('❌ 错误: 当前页面内容为空字符串');
                    if (mounted) {
                      HapticFeedback.heavyImpact();
                      setState(() => _errorMessage = '当前页面内容为空字符串');
                    }
                    return;
                  }

                  debugPrint('✅ 当前页面内容长度: ${currentContent.length} 字符');
                  debugPrint(
                      '内容预览: ${currentContent.substring(0, currentContent.length.clamp(0, 50))}...');
                  debugPrint('───────────────────────────────────────');
                  debugPrint('📤 准备调用 ttsNotifier.play()...');

                  await ttsNotifier.play(text: currentContent);

                  debugPrint('✅ ttsNotifier.play() 调用完成');
                  debugPrint('═══════════════════════════════════════');

                  if (mounted) {
                    HapticFeedback.lightImpact();
                    setState(() => _errorMessage = null);
                  }
                }
              } catch (e) {
                if (mounted) {
                  HapticFeedback.heavyImpact();
                  setState(() => _errorMessage = '操作失败: $e');
                }
              }
            },
            colorScheme: colorScheme,
            theme: theme,
          ),

          // 下一句
          _buildControlButton(
            icon: Icons.skip_next_rounded,
            label: '下一句',
            onPressed: () async {
              try {
                HapticFeedback.lightImpact();
                await ttsNotifier.next();
                if (mounted) {
                  setState(() => _errorMessage = null);
                }
              } catch (e) {
                if (mounted) {
                  HapticFeedback.heavyImpact();
                  setState(() => _errorMessage = '下一句失败: $e');
                }
              }
            },
            colorScheme: colorScheme,
            theme: theme,
          ),
        ],
      ),
    );
  }

  /// 构建主播放/停止按钮（简洁版）
  Widget _buildMainPlayStopButton({
    required bool isPlaying,
    required bool isPaused,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    IconData icon;
    String label;
    Color buttonColor;

    if (isPlaying) {
      icon = Icons.stop_circle;
      label = '停止';
      buttonColor = Colors.red.shade600;
    } else if (isPaused) {
      icon = Icons.stop_circle;
      label = '停止';
      buttonColor = Colors.orange.shade600;
    } else {
      icon = Icons.play_circle_filled;
      label = '播放';
      buttonColor = colorScheme.primary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: buttonColor,
          shape: const CircleBorder(),
          elevation: isPlaying ? 4 : 2,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(
                icon,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: buttonColor,
          ),
        ),
      ],
    );
  }

  /// 构建单个控制按钮
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
    required ThemeData theme,
    bool isPrimary = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isPrimary
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          elevation: isPrimary ? 4 : 0,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(isPrimary ? 16 : 12),
              child: Icon(
                icon,
                size: isPrimary ? 40 : 28,
                color:
                    isPrimary ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isPrimary
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// 构建定时停止
  Widget _buildStopTimer(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _stopMinutes > 0
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.timer_outlined,
              color: _stopMinutes > 0
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.5),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '定时停止',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _stopMinutes > 0 ? '${_stopMinutes.ceil()} 分钟后停止' : '不限时',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _stopMinutes > 0
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: _stopMinutes > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Slider(
                  value: _stopMinutes,
                  onChanged: (value) {
                    setState(() {
                      _stopMinutes = value;
                    });
                    _startStopTimer();
                  },
                  min: 0.0,
                  max: 60.0,
                  divisions: 12,
                  label: _stopMinutes > 0 ? '${_stopMinutes.ceil()} 分钟' : '不限时',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建滑块控制
  Widget _buildSlider({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        value.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Slider(
                  value: value,
                  onChanged: onChanged,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: value.toStringAsFixed(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 显示TTS设置面板
///
/// 从底部弹出一个TTS设置面板
///
/// 参数:
/// - [context]: BuildContext
///
/// 返回:
/// - Future<void>
Future<void> showTtsSettingsSheet(BuildContext context) {
  final theme = Theme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    builder: (context) => const TtsSettingsSheet(),
  );
}
