import 'package:flutter/material.dart';

/// 首页导航项模型。
///
/// 壳层只依赖这个结构来绘制导航，不关心页面内部实现。
class HomeNavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;

  const HomeNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.page,
  });
}
