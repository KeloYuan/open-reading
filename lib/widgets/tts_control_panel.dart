import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tts_service.dart';
import '../utils/theme_mixin.dart';

/// TTS控制面板
/// 提供优雅的语音朗读控制界面，保持应用的毛玻璃主题风格
class TtsControlPanel extends StatefulWidget {
  final String? textToRead;
  final VoidCallback? onClose;

  const TtsControlPanel({super.key, this.textToRead, this.onClose});

  @override
  State<TtsControlPanel> createState() => _TtsControlPanelState();
}

class _TtsControlPanelState extends State<TtsControlPanel>
    with ThemeMixin, TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // 启动动画
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _slideController.reverse();
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TtsService>(
      builder: (context, ttsService, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.9),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).dividerColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(context, ttsService),
                      _buildControls(context, ttsService),
                      _buildSettings(context, ttsService),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, TtsService ttsService) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: getAccentColor(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.record_voice_over_rounded,
              color: getAccentColor(context),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '语音朗读',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: getTextColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ttsService.isPlaying
                      ? (ttsService.isPaused ? '已暂停' : '正在播放')
                      : '准备就绪',
                  style: TextStyle(
                    fontSize: 14,
                    color: getTextColor(context).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _close,
            icon: Icon(
              Icons.close_rounded,
              color: getTextColor(context).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, TtsService ttsService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            context: context,
            icon: Icons.skip_previous_rounded,
            label: '上一段',
            onPressed: () {
              // TODO: 实现上一段功能
            },
            isEnabled: false,
          ),
          _buildMainControlButton(context, ttsService),
          _buildControlButton(
            context: context,
            icon: Icons.skip_next_rounded,
            label: '下一段',
            onPressed: () {
              // TODO: 实现下一段功能
            },
            isEnabled: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMainControlButton(BuildContext context, TtsService ttsService) {
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
      label = '播放';
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
            color: getAccentColor(context),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: getAccentColor(context).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: getTextColor(context).withOpacity(0.8),
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
    bool isEnabled = true,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isEnabled
                ? getTextColor(context).withOpacity(0.1)
                : getTextColor(context).withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
          ),
          child: IconButton(
            onPressed: isEnabled ? onPressed : null,
            icon: Icon(
              icon,
              color: isEnabled
                  ? getTextColor(context).withOpacity(0.8)
                  : getTextColor(context).withOpacity(0.3),
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
                ? getTextColor(context).withOpacity(0.8)
                : getTextColor(context).withOpacity(0.3),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSettings(BuildContext context, TtsService ttsService) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
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
          _buildSliderSetting(
            context: context,
            title: '音调',
            value: ttsService.speechPitch,
            onChanged: (value) => ttsService.setPitch(value),
            min: 0.5,
            max: 2.0,
            icon: Icons.tune_rounded,
          ),
          if (ttsService.isPlaying) ...[
            const SizedBox(height: 16),
            _buildProgressIndicator(context, ttsService),
          ],
        ],
      ),
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
    return Row(
      children: [
        Icon(icon, color: getAccentColor(context), size: 20),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: getTextColor(context).withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: getAccentColor(context),
              inactiveTrackColor: getAccentColor(
                context,
              ).withOpacity(0.2),
              thumbColor: getAccentColor(context),
              overlayColor: getAccentColor(context).withOpacity(0.2),
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
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 12,
              color: getTextColor(context).withOpacity(0.6),
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(BuildContext context, TtsService ttsService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.timeline_rounded,
              color: getAccentColor(context),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              '播放进度',
              style: TextStyle(
                fontSize: 14,
                color: getTextColor(context).withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: ttsService.playbackProgress,
          backgroundColor: getAccentColor(context).withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(getAccentColor(context)),
        ),
      ],
    );
  }
}
