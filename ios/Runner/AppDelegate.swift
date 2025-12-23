import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 设置状态栏样式为深色内容（适合浅色背景）
    if #available(iOS 13.0, *) {
      UIApplication.shared.statusBarStyle = .darkContent
    } else {
      UIApplication.shared.statusBarStyle = .default
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
