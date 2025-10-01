import 'package:flutter/material.dart';

// 自定义滑块拇指形状
class CustomSliderThumbShape extends SliderComponentShape {
  final double enabledThumbRadius;
  final Color thumbColor;

  const CustomSliderThumbShape({
    required this.enabledThumbRadius,
    required this.thumbColor,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(enabledThumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // 外圈阴影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center + const Offset(0, 2), enabledThumbRadius, shadowPaint);

    // 主体圆圈
    final mainPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, enabledThumbRadius, mainPaint);

    // 内圈高光
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, enabledThumbRadius * 0.5, highlightPaint);

    // 边框
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, enabledThumbRadius, borderPaint);
  }
}

// 自定义滑块轨道形状
class CustomSliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = true,
    double additionalActiveTrackHeight = 2,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }

    final ColorTween activeTrackColorTween = ColorTween(
      begin: sliderTheme.disabledActiveTrackColor,
      end: sliderTheme.activeTrackColor,
    );
    final ColorTween inactiveTrackColorTween = ColorTween(
      begin: sliderTheme.disabledInactiveTrackColor,
      end: sliderTheme.inactiveTrackColor,
    );

    final activeTrackColor = activeTrackColorTween.evaluate(enableAnimation)!;
    final inactiveTrackColor = inactiveTrackColorTween.evaluate(enableAnimation)!;

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final trackRadius = Radius.circular(sliderTheme.trackHeight! / 2);
    final activeTrackRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx,
      trackRect.bottom,
    );

    // 绘制非活动轨道（带阴影）
    final inactiveTrackPaint = Paint()
      ..color = inactiveTrackColor
      ..style = PaintingStyle.fill;
    final inactiveTrackRRect = RRect.fromRectAndRadius(trackRect, trackRadius);
    
    // 非活动轨道阴影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    context.canvas.drawRRect(
      inactiveTrackRRect.shift(const Offset(0, 1)), 
      shadowPaint,
    );
    
    context.canvas.drawRRect(inactiveTrackRRect, inactiveTrackPaint);

    // 绘制活动轨道（带渐变）
    if (activeTrackRect.width > 0) {
      final activeTrackRRect = RRect.fromRectAndRadius(activeTrackRect, trackRadius);
      
      // 创建渐变
      final gradient = LinearGradient(
        colors: [
          activeTrackColor.withValues(alpha: 0.8),
          activeTrackColor,
          activeTrackColor.withValues(alpha: 0.9),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      
      final gradientPaint = Paint()
        ..shader = gradient.createShader(activeTrackRect)
        ..style = PaintingStyle.fill;
      
      context.canvas.drawRRect(activeTrackRRect, gradientPaint);
      
      // 活动轨道高光
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      final highlightRect = Rect.fromLTRB(
        activeTrackRect.left,
        activeTrackRect.top,
        activeTrackRect.right,
        activeTrackRect.top + activeTrackRect.height * 0.4,
      );
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(highlightRect, trackRadius),
        highlightPaint,
      );
    }
  }
}