import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/tts/enhanced_tts_handler.dart';
import '../../services/tts/system_tts.dart';
import '../../services/tts/tts_preferences.dart';

/// 增强TTS朗读面板
/// 集成anx-reader的TTS界面设计
class EnhancedTtsPanel extends StatefulWidget {
  final Function? getCurrentText;
  final Function? getNextText;
  final Function? getPrevText;
  final VoidCallback? onClose;

  const EnhancedTtsPanel({
    super.key,
    this.getCurrentText,
    this.getNextText,
    this.getPrevText,
    this.onClose,
  });

  @override
  State<EnhancedTtsPanel> createState() => _EnhancedTtsPanelState();
}

class _EnhancedTtsPanelState extends State<EnhancedTtsPanel>
    with TickerProviderStateMixin {
  late EnhancedTtsHandler _ttsHandler;
  late AnimationController _waveAnimationController;
  late AnimationController _progressAnimationController;

  // TTS设置
  double _volume = 1.0;
  double _pitch = 1.0;
  double _rate = 0.5;
  String _selectedLanguage = 'zh-CN';
  String _selectedVoice = '';
  String? _selectedEngine;

  // 界面状态
  bool _showAdvancedSettings = false;
  bool _isInitializing = true;

  // 可用选项
  List<String> _availableLanguages = [];
  List<Map<String, String>> _availableVoices = [];
  List<String> _availableEngines = [];

  // 定时器
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeTts();
  }

  void _initializeAnimations() {
    _waveAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _progressAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  Future<void> _initializeTts() async {
    _ttsHandler = EnhancedTtsHandler();

    // 初始化TTS处理器
    await _ttsHandler.initialize(
      getCurrentText: widget.getCurrentText,
      getNextText: widget.getNextText,
      getPrevText: widget.getPrevText,
    );

    // 加载设置
    await _loadSettings();

    // 获取可用选项
    _availableLanguages = await _ttsHandler.getLanguages();
    _availableVoices = await _ttsHandler.getVoices();
    await _loadAvailableEngines();

    // 监听TTS状态变化
    _ttsHandler.stateNotifier.addListener(_onTtsStateChanged);

    setState(() {
      _isInitializing = false;
    });
  }

  Future<void> _loadSettings() async {
    setState(() {
      _volume = _ttsHandler.volume;
      _pitch = _ttsHandler.pitch;
      _rate = _ttsHandler.rate;
      _selectedLanguage = _ttsHandler.language;
      _selectedVoice = _ttsHandler.voice;
      _selectedEngine = TtsPreferences().ttsEngine;
    });
  }

  Future<void> _loadAvailableEngines() async {
    // 只在Android平台获取TTS引擎列表
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final engines = await SystemTts().getAvailableEngines();
        setState(() {
          _availableEngines = engines.map((e) => e.toString()).toList();
        });
      } catch (e) {
        debugPrint('获取TTS引擎列表失败: $e');
      }
    }
  }

  void _onTtsStateChanged() {
    if (mounted) {
      setState(() {});

      if (_ttsHandler.isPlaying) {
        _waveAnimationController.repeat();
      } else {
        _waveAnimationController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: screenSize.height * 0.85,
        minHeight: 320,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽手柄
          _buildDragHandle(),

          // 标题栏
          _buildHeader(),

          if (_isInitializing)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 播放状态指示器
                    _buildPlaybackIndicator(),

                    const SizedBox(height: 24),

                    // 主要控制按钮
                    _buildMainControls(),

                    const SizedBox(height: 32),

                    // 基础设置
                    _buildBasicSettings(),

                    // 高级设置
                    if (_showAdvancedSettings) ...[
                      const SizedBox(height: 24),
                      _buildAdvancedSettings(),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.record_voice_over,
            color: scheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '语音朗读',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _showAdvancedSettings = !_showAdvancedSettings;
              });
            },
            icon: Icon(
              _showAdvancedSettings ? Icons.expand_less : Icons.expand_more,
              color: scheme.onSurface,
            ),
            tooltip: _showAdvancedSettings ? '收起设置' : '展开设置',
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(Icons.close, color: scheme.onSurface),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackIndicator() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: AnimatedBuilder(
          animation: _waveAnimationController,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(200, 80),
              painter: SoundWavePainter(
                animation: _waveAnimationController,
                isPlaying: _ttsHandler.isPlaying,
                color: scheme.primary,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.skip_previous,
            onPressed: _ttsHandler.isPlaying || _ttsHandler.isPaused
                ? () => _ttsHandler.skipToPrevious()
                : null,
            tooltip: '上一段',
          ),
          _buildControlButton(
            icon: _ttsHandler.isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            onPressed: () {
              if (_ttsHandler.isPlaying) {
                _ttsHandler.pause();
              } else {
                _ttsHandler.play();
              }
            },
            tooltip: _ttsHandler.isPlaying ? '暂停' : '播放',
            isPrimary: true,
          ),
          _buildControlButton(
            icon: Icons.skip_next,
            onPressed: _ttsHandler.isPlaying || _ttsHandler.isPaused
                ? () => _ttsHandler.skipToNext()
                : null,
            tooltip: '下一段',
          ),
          _buildControlButton(
            icon: Icons.stop,
            onPressed: _ttsHandler.isPlaying || _ttsHandler.isPaused
                ? () => _ttsHandler.stop()
                : null,
            tooltip: '停止',
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool isPrimary = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Container(
        width: isPrimary ? 64 : 48,
        height: isPrimary ? 64 : 48,
        decoration: BoxDecoration(
          color: isPrimary
              ? scheme.primary
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(isPrimary ? 32 : 24),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: isPrimary ? 32 : 24,
            color: isPrimary
                ? scheme.onPrimary
                : (onPressed != null
                      ? scheme.onSurface
                      : scheme.onSurface.withValues(alpha: 0.38)),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicSettings() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSliderSetting(
            title: '音量',
            value: _volume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: (value) {
              setState(() {
                _volume = value;
              });
              _ttsHandler.setVolume(value);
            },
            icon: Icons.volume_up,
          ),
          const SizedBox(height: 16),
          _buildSliderSetting(
            title: '语速',
            value: _rate,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            onChanged: (value) {
              setState(() {
                _rate = value;
              });
              _ttsHandler.setRate(value);
            },
            icon: Icons.speed,
          ),
          const SizedBox(height: 16),
          _buildSliderSetting(
            title: '音调',
            value: _pitch,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            onChanged: (value) {
              setState(() {
                _pitch = value;
              });
              _ttsHandler.setPitch(value);
            },
            icon: Icons.graphic_eq,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 16),

          // 语言选择
          _buildDropdownSetting(
            title: '语言',
            value: _selectedLanguage,
            items: _availableLanguages
                .map(
                  (lang) => DropdownMenuItem(
                    value: lang,
                    child: Text(_getLanguageDisplayName(lang)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedLanguage = value;
                });
                _ttsHandler.setLanguage(value);
              }
            },
            icon: Icons.language,
          ),

          const SizedBox(height: 16),

          // TTS引擎选择（仅Android）
          if (_availableEngines.isNotEmpty && !kIsWeb && Platform.isAndroid)
            Column(
              children: [
                _buildDropdownSetting(
                  title: 'TTS引擎',
                  value: _selectedEngine ?? '',
                  items: [
                    const DropdownMenuItem(value: '', child: Text('系统默认')),
                    ..._availableEngines.map(
                      (engine) => DropdownMenuItem(
                        value: engine,
                        child: Text(_getEngineDisplayName(engine)),
                      ),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value != null) {
                      final engineToSet = value.isEmpty ? null : value;
                      setState(() {
                        _selectedEngine = engineToSet;
                      });

                      // 保存设置
                      TtsPreferences().ttsEngine = engineToSet;

                      // 提示用户需要重启TTS
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('TTS引擎已更改，请重新打开朗读面板以应用更改'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  icon: Icons.speaker,
                ),
                const SizedBox(height: 16),
              ],
            ),

          // 语音选择
          if (_availableVoices.isNotEmpty)
            _buildDropdownSetting(
              title: '语音',
              value: _selectedVoice,
              items: [
                const DropdownMenuItem(value: '', child: Text('系统默认')),
                ..._availableVoices
                    .where((voice) => voice['locale'] == _selectedLanguage)
                    .map(
                      (voice) => DropdownMenuItem(
                        value: voice['name'] ?? '',
                        child: Text(voice['name'] ?? ''),
                      ),
                    )
                    .toList(),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedVoice = value;
                  });
                  _ttsHandler.setVoice(value);
                }
              },
              icon: Icons.person,
            ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(1),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownSetting<T>({
    required String title,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            underline: Container(
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ],
    );
  }

  String _getLanguageDisplayName(String locale) {
    switch (locale) {
      case 'zh-CN':
        return '中文(简体)';
      case 'zh-TW':
        return '中文(繁体)';
      case 'en-US':
        return 'English (US)';
      case 'en-GB':
        return 'English (UK)';
      case 'ja-JP':
        return '日本語';
      case 'ko-KR':
        return '한국어';
      default:
        return locale;
    }
  }

  String _getEngineDisplayName(String engine) {
    // 简化引擎包名显示
    if (engine.contains('google')) {
      return 'Google TTS';
    } else if (engine.contains('samsung')) {
      return 'Samsung TTS';
    } else if (engine.contains('oppo') || engine.contains('coloros')) {
      return 'OPPO TTS';
    } else if (engine.contains('xiaomi') || engine.contains('miui')) {
      return '小米 TTS';
    } else if (engine.contains('huawei')) {
      return '华为 TTS';
    } else if (engine.contains('vivo')) {
      return 'vivo TTS';
    } else if (engine.contains('android')) {
      return '系统 TTS';
    }
    // 提取包名最后一部分作为显示名
    final parts = engine.split('.');
    return parts.isNotEmpty ? parts.last : engine;
  }

  @override
  void dispose() {
    _waveAnimationController.dispose();
    _progressAnimationController.dispose();
    _autoHideTimer?.cancel();
    _ttsHandler.stateNotifier.removeListener(_onTtsStateChanged);
    super.dispose();
  }
}

/// 音波绘制器
class SoundWavePainter extends CustomPainter {
  final Animation<double> animation;
  final bool isPlaying;
  final Color color;

  SoundWavePainter({
    required this.animation,
    required this.isPlaying,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: isPlaying ? 0.8 : 0.3)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final barWidth = 4.0;
    final barSpacing = 8.0;
    final numBars = (size.width / (barWidth + barSpacing)).floor();

    for (int i = 0; i < numBars; i++) {
      final x = i * (barWidth + barSpacing) + barWidth / 2;
      final progress = (animation.value + i * 0.1) % 1.0;
      final height = isPlaying
          ? (20 + 40 * (0.5 + 0.5 * math.sin(progress * 2 * math.pi)))
          : 10;

      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SoundWavePainter oldDelegate) {
    return animation.value != oldDelegate.animation.value ||
        isPlaying != oldDelegate.isPlaying;
  }
}
