import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// 全局系统UI管理器
///
/// 负责：
/// - 提供“沉浸式锁”，当阅读页加锁后，其他页面（首页/主题切换）不应覆盖系统UI设置
/// - 统一提供进入/退出沉浸式的方法
class SystemUiManager {
  static bool _immersiveLocked = false;

  /// 是否已加锁（阅读中）
  static bool get isImmersiveLocked => _immersiveLocked;

  /// 加锁：进入阅读页时调用
  static void lockImmersive() {
    _immersiveLocked = true;
  }

  /// 解锁：离开阅读页时调用
  static void unlockImmersive() {
    _immersiveLocked = false;
  }

  /// 进入沉浸式模式（隐藏状态栏和系统导航栏/小白条）
  static void enterImmersive({bool sticky = true}) {
    SystemChrome.setEnabledSystemUIMode(
      sticky ? SystemUiMode.immersiveSticky : SystemUiMode.immersive,
      overlays: [],
    );
  }

  /// 恢复系统UI（显示状态栏和导航栏）
  static void exitImmersive({
    Color? navigationBarColor,
    Brightness? navIconBrightness,
  }) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );

    if (navigationBarColor != null || navIconBrightness != null) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          systemNavigationBarColor: navigationBarColor ?? Colors.transparent,
          systemNavigationBarIconBrightness:
              navIconBrightness ?? Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    }
  }
}

