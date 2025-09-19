import 'package:flutter/material.dart';

extension ColorExtension on Color {
  // 使用 0.0 - 1.0 的分量值进行更新，未提供则沿用当前分量
  Color withValues({double? alpha, double? red, double? green, double? blue}) {
    final aInt = alpha != null
        ? (alpha.clamp(0.0, 1.0) * 255).round()
        : (a * 255.0).round() & 0xff;
    final rInt = red != null
        ? (red.clamp(0.0, 1.0) * 255).round()
        : (r * 255.0).round() & 0xff;
    final gInt = green != null
        ? (green.clamp(0.0, 1.0) * 255).round()
        : (g * 255.0).round() & 0xff;
    final bInt = blue != null
        ? (blue.clamp(0.0, 1.0) * 255).round()
        : (b * 255.0).round() & 0xff;

    return Color.fromARGB(aInt, rInt, gInt, bInt);
  }

  // 使用 0.0 - 1.0 的透明度
  Color withOpacity(double opacity) {
    final aInt = (opacity.clamp(0.0, 1.0) * 255).round();
    return withAlpha(aInt);
  }

  int toARGB32() {
    // 直接使用现有通道（0-255）拼装 ARGB 32 位整数
    return (((a * 255.0).round() & 0xff) << 24) |
        (((r * 255.0).round() & 0xff) << 16) |
        (((g * 255.0).round() & 0xff) << 8) |
        ((b * 255.0).round() & 0xff);
  }
}
