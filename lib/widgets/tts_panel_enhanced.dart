import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tts_service.dart';

/// 增强版TTS控制面板
/// 采用与其他面板一致的设计风格
class TtsPanelEnhanced extends StatefulWidget {
  final String? textToRead;

  const TtsPanelEnhanced({super.key, this.textToRead});

  @override
  State<TtsPanelEnhanced> createState() => _TtsPanelEnhancedState();
}

class _TtsPanelEnhancedState extends State<TtsPanelEnhanced> {
  @override
  Widget build(BuildContext context) {
    return Consumer<TtsService>(
      builder: (context, ttsService, child) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                decoration: BoxDecoration(
                  color: _getModalDecoration(),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    // 拖拽指示器
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _getModalIconColor(),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),

                    // 主控制区域
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // 主播放控制
                            _buildMainControl(context, ttsService),
                            const SizedBox(height: 32),

                            // 语音设置
                            _buildVoiceSettings(context, ttsService),

                            // 播放进度（如果正在播放）
                            if (ttsService.isPlaying) ...[
                              const SizedBox(height: 24),
                              _buildProgress(context, ttsService),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainControl(BuildContext context, TtsService ttsService) {
    return Column(
      children: [
        // 状态指示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getModalAccentColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.record_voice_over_rounded,
                color: _getModalAccentColor(),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                ttsService.isPlaying
                    ? (ttsService.isPaused ? '已暂停' : '正在朗读')
                    : '准备就绪',
                style: TextStyle(
                  color: _getModalAccentColor(),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 主控制按钮组
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              context: context,
              icon: Icons.skip_previous_rounded,
              label: '上一段',
              onPressed: null, // TODO: 实现
              isSecondary: true,
            ),
            _buildMainPlayButton(context, ttsService),
            _buildControlButton(
              context: context,
              icon: Icons.skip_next_rounded,
              label: '下一段',
              onPressed: null, // TODO: 实现
              isSecondary: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainPlayButton(BuildContext context, TtsService ttsService) {
    IconData icon;
    String label;
    VoidCallback? onPressed;

    if (ttsService.isPlaying && !ttsService.isPaused) {
      icon = Icons.pause_rounded;
      label = '暂停';
      onPressed = () => ttsService.pause();
    } else if (ttsService.isPaused) {
      icon = Icons.play_arrow_rounded;
      label = '继续';
      onPressed = () => ttsService.resume();
    } else {
      icon = Icons.play_arrow_rounded;
      label = '开始朗读';
      onPressed = widget.textToRead != null
          ? () => ttsService.speak(widget.textToRead!)
          : null;
    }

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _getModalAccentColor(),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _getModalAccentColor().withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _getModalTextColor().withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isSecondary = false,
  }) {
    final isEnabled = onPressed != null;

    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isEnabled
                ? (isSecondary
                      ? _getModalTextColor().withOpacity(0.1)
                      : _getModalAccentColor().withOpacity(0.1))
                : _getModalTextColor().withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: isEnabled
                  ? (isSecondary
                        ? _getModalTextColor().withOpacity(0.8)
                        : _getModalAccentColor())
                  : _getModalTextColor().withOpacity(0.3),
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isEnabled
                ? _getModalTextColor().withOpacity(0.8)
                : _getModalTextColor().withOpacity(0.3),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceSettings(BuildContext context, TtsService ttsService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '语音设置',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _getModalTextColor(),
          ),
        ),
        const SizedBox(height: 16),

        // 语速调节
        _buildSliderSetting(
          context: context,
          title: '语速',
          value: ttsService.speechRate,
          onChanged: (value) => ttsService.setSpeechRate(value),
          min: 0.1,
          max: 1.0,
          icon: Icons.speed_rounded,
        ),

        const SizedBox(height: 16),

        // 音调调节
        _buildSliderSetting(
          context: context,
          title: '音调',
          value: ttsService.speechPitch,
          onChanged: (value) => ttsService.setPitch(value),
          min: 0.5,
          max: 2.0,
          icon: Icons.tune_rounded,
        ),
      ],
    );
  }

  Widget _buildSliderSetting({
    required BuildContext context,
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
    required double min,
    required double max,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getModalTextColor().withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: _getModalAccentColor(), size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: _getModalTextColor().withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 14,
                  color: _getModalAccentColor(),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _getModalAccentColor(),
              inactiveTrackColor: _getModalAccentColor().withOpacity(0.2),
              thumbColor: _getModalAccentColor(),
              overlayColor: _getModalAccentColor().withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(BuildContext context, TtsService ttsService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getModalAccentColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timeline_rounded,
                color: _getModalAccentColor(),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                '朗读进度',
                style: TextStyle(
                  fontSize: 14,
                  color: _getModalTextColor().withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: ttsService.playbackProgress,
            backgroundColor: _getModalAccentColor().withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(_getModalAccentColor()),
          ),
        ],
      ),
    );
  }

  // 获取模态装饰
  Color _getModalDecoration() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode
        ? const Color(0xFF1E1E1E).withOpacity(0.95)
        : const Color(0xFFFFFBF0).withOpacity(0.95);
  }

  // 获取模态文本颜色
  Color _getModalTextColor() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? Colors.white : const Color(0xFF2C2C2C);
  }

  // 获取模态强调色
  Color _getModalAccentColor() {
    return Theme.of(context).colorScheme.primary;
  }

  // 获取模态图标颜色
  Color _getModalIconColor() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode
        ? Colors.white.withOpacity(0.6)
        : Colors.black.withOpacity(0.6);
  }
}
