import 'package:flutter/material.dart';

extension ColorExtension on Color {
  /// 将Color转换为32位ARGB整数
  /// 替代已弃用的 color.value
  /// 在Flutter 3.27+中，Color组件是浮点数(0.0-1.0)，需要转换为整数
  int toARGB32() {
    return (a * 255).round() << 24 |
        (r * 255).round() << 16 |
        (g * 255).round() << 8 |
        (b * 255).round();
  }
}
